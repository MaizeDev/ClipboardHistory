//
//  HistoryPanelViewState.swift
//  ClipboardHistory
//

import Foundation
import Observation

struct HistoryPanelCommandRequest: Equatable {
    let sequence: Int
    let command: HistoryPanelCommand
}

/// 浮窗的界面状态。
///
/// 浮窗对象和它里面的 SwiftUI 视图在整个 App 生命周期内只创建一次，
/// 所以搜索词、分区等状态必须放在这里，才能在每次关闭时统一重置。
@Observable
@MainActor
final class HistoryPanelViewState {

    private static let undoWindow: Duration = .seconds(5)
    private static let maximumUndoCount = 20

    /// 撤销栈里所有快照的总大小上限。连续删除大图片时，
    /// 仅按条数限制会让这些完整副本占用几百 MB 内存。
    private static let maximumUndoBytes = 64 * 1024 * 1024

    var searchText = ""
    var selectedSection = HistoryPanelSection.history

    /// 每次关闭浮窗时更换。
    /// `HistoryListView` 用它作为 `.id`，换新值就会重建列表，
    /// 从而清掉选中项和滚动位置。
    private(set) var presentationID = UUID()

    private(set) var searchFocusRequest = 0

    /// 浮窗每次显示时加一。
    /// 卡片据此重新检查文件是否还在：浮窗关着的时候文件可能已经被删除或移动。
    private(set) var showCount = 0
    private(set) var commandRequest: HistoryPanelCommandRequest?

    /// 键盘焦点是否在历史列表上。
    /// 为 true 时，Delete / Backspace 才会删除选中的记录；
    /// 为 false（默认，焦点在搜索框）时，它们只用来编辑搜索框里的文字。
    private(set) var isListFocused = false

    /// 最近删除的记录副本，最后删除的在末尾。
    /// 几秒内没有新的删除或撤销，就会被清空，之后不能再撤销。
    private(set) var undoStack: [HistoryItemSnapshot] = []

    private var commandSequence = 0

    @ObservationIgnored
    private var undoDismissTask: Task<Void, Never>?

    /// 浮窗底部短暂显示的错误/提示信息。
    private(set) var noticeMessage: String?

    private static let noticeDuration: Duration = .seconds(3)

    @ObservationIgnored
    private var noticeDismissTask: Task<Void, Never>?

    var undoCount: Int {
        undoStack.count
    }

    func showNotice(_ message: String) {
        noticeDismissTask?.cancel()
        noticeMessage = message

        noticeDismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.noticeDuration)

            guard !Task.isCancelled else {
                return
            }

            self?.noticeMessage = nil
        }
    }

    func requestSearchFocus() {
        searchFocusRequest += 1
    }

    func send(_ command: HistoryPanelCommand) {
        commandSequence += 1
        commandRequest = HistoryPanelCommandRequest(
            sequence: commandSequence,
            command: command
        )
    }

    func noteShown() {
        showCount += 1
    }

    func focusList() {
        guard !isListFocused else {
            return
        }

        isListFocused = true
    }

    func focusSearch() {
        guard isListFocused else {
            return
        }

        isListFocused = false
    }

    /// 浮窗关闭时调用，让下一次打开时是一个干净的界面。
    /// 注意：不清除可撤销的删除，它们由自己的计时器过期。
    func prepareForNextPresentation() {
        searchText = ""
        selectedSection = .history
        commandRequest = nil
        isListFocused = false
        presentationID = UUID()

        noticeDismissTask?.cancel()
        noticeDismissTask = nil
        noticeMessage = nil
    }

    // MARK: - Undo delete

    func offerUndo(for snapshot: HistoryItemSnapshot) {
        undoStack.append(snapshot)

        if undoStack.count > Self.maximumUndoCount {
            undoStack.removeFirst(undoStack.count - Self.maximumUndoCount)
        }

        var totalBytes = undoStack.reduce(0) { partial, snapshot in
            partial + snapshotBytes(snapshot)
        }

        // 条数没超但总大小超了时，丢掉最早的快照，但至少保留一条。
        while totalBytes > Self.maximumUndoBytes, undoStack.count > 1 {
            let removed = undoStack.removeFirst()
            totalBytes -= snapshotBytes(removed)
        }

        restartUndoTimer()
    }

    /// 清空全部可撤销的删除。
    /// 清空所有历史记录后，之前的删除快照不应该还能把记录恢复回来。
    func clearUndoHistory() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        undoStack.removeAll()
    }

    /// 取出最近一次删除的副本。取出后由调用方负责恢复。
    func popUndoSnapshot() -> HistoryItemSnapshot? {
        guard let snapshot = undoStack.popLast() else {
            return nil
        }

        if undoStack.isEmpty {
            undoDismissTask?.cancel()
            undoDismissTask = nil
        } else {
            restartUndoTimer()
        }

        return snapshot
    }

    private func snapshotBytes(_ snapshot: HistoryItemSnapshot) -> Int {
        snapshot.contentData.count + (snapshot.formatsData?.count ?? 0)
    }

    private func restartUndoTimer() {
        undoDismissTask?.cancel()
        undoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: Self.undoWindow)

            guard !Task.isCancelled else {
                return
            }

            self?.undoStack.removeAll()
        }
    }
}
