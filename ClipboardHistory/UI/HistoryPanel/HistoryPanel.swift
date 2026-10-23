//
//  HistoryPanel.swift
//  ClipboardHistory
//

import AppKit
import SwiftUI

@MainActor
final class HistoryPanel: NSPanel {

    private static let panelSize = NSSize(
        width: HistoryPanelLayout.width,
        height: HistoryPanelLayout.height
    )

    /// 因失去 key 状态而自动隐藏之后，这段时间内忽略 `toggle()` 的重新显示。
    /// 点击菜单栏图标时，面板会先失去 key 被隐藏，随后图标的 action 才触发；
    /// 不加这个间隔，面板会被刚关掉又立刻弹出。
    private static let reopenSuppressionInterval: TimeInterval = 0.25

    private let viewState = HistoryPanelViewState()
    private var lastResignHideDate = Date.distantPast

    private static let positionOffsetKey = "historyPanelPositionOffset"

    /// 用户拖动浮窗后，相对“屏幕可见区域中心”的偏移。下次打开时沿用。
    private var positionOffset = HistoryPanel.loadPositionOffset()

    /// 删除成功时返回被删除记录的副本，用于“撤销删除”。
    private let onDelete: (HistoryRow) -> HistoryItemSnapshot?
    private let onRestore: (HistoryItemSnapshot) -> Bool
    private let onTogglePin: (HistoryRow) -> Void
    private let onToggleFavorite: (HistoryRow) -> Void
    private let onChoose: (HistoryRow, ClipboardCopyMode) -> Bool
    private let preferences: AppPreferences

    init(
        store: HistoryStore,
        preferences: AppPreferences,
        onDelete: @escaping (HistoryRow) -> HistoryItemSnapshot?,
        onRestore: @escaping (HistoryItemSnapshot) -> Bool,
        onTogglePin: @escaping (HistoryRow) -> Void,
        onToggleFavorite: @escaping (HistoryRow) -> Void,
        onChoose: @escaping (HistoryRow, ClipboardCopyMode) -> Bool
    ) {
        self.preferences = preferences
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onTogglePin = onTogglePin
        self.onToggleFavorite = onToggleFavorite
        self.onChoose = onChoose

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        configureContent(store: store)
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        // 点击任何地方，先把焦点放回搜索框；
        // 如果点的是卡片，卡片的点击回调随后会把焦点切到列表。
        if event.type == .leftMouseDown {
            viewState.focusSearch()

            if isInDragRegion(event) {
                if event.clickCount == 2 {
                    // 双击标题栏：恢复到屏幕中央。
                    resetPosition()
                } else {
                    performDrag(with: event)
                }
                return
            }
        }

        guard event.type == .keyDown else {
            super.sendEvent(event)
            return
        }

        if let fieldEditor = firstResponder as? NSTextView {
            // 输入法组合中的按键一律交给输入框。
            if fieldEditor.hasMarkedText() {
                super.sendEvent(event)
                return
            }

            // 搜索框里有文字时，⌘Z 留给输入框自己撤销输入。
            if fieldEditor.string.isEmpty,
               isUndoDeleteShortcut(event),
               performUndoDelete() {
                return
            }
        } else if isUndoDeleteShortcut(event),
                  performUndoDelete() {
            return
        }

        // 搜索框里有内容时，Esc 先清空搜索；再按一次才关闭浮窗。
        if HistoryPanelKeyboard.isEscape(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ),
           !viewState.searchText.isEmpty {
            viewState.searchText = ""
            viewState.focusSearch()
            viewState.requestSearchFocus()
            return
        }

        guard let command = HistoryPanelKeyboard.command(
            keyCode: event.keyCode,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifierFlags: event.modifierFlags
        ) else {
            // 输入文字、粘贴等：焦点回到搜索框。
            viewState.focusSearch()
            super.sendEvent(event)
            return
        }

        switch command {
        case .deleteSelection:
            // 只有焦点在列表上（用方向键或点击选过卡片）时才删除记录。
            // 焦点在搜索框时，Delete 只用来编辑搜索框里的文字。
            guard viewState.isListFocused else {
                super.sendEvent(event)
                return
            }

        case .moveSelection:
            // 焦点在搜索框时，第一次按方向键只是“进入列表”：
            // 选中当前高亮的候选项（通常是第一条），不移动。
            // 进入列表之后再按，才会真正移动。
            guard viewState.isListFocused else {
                viewState.focusList()
                return
            }

        case .selectItem:
            viewState.focusList()

        default:
            break
        }

        guard !event.isARepeat || command.allowsKeyRepeat else {
            return
        }

        viewState.send(command)
    }

    // MARK: - Position

    /// 顶部标题栏（除关闭按钮外）是拖动区域。
    /// 浮窗是无边框窗口，内容又是 SwiftUI，直接拖窗口背景不起作用，所以单独处理。
    private func isInDragRegion(_ event: NSEvent) -> Bool {
        let point = event.locationInWindow

        return point.y >= frame.height - HistoryPanelLayout.headerHeight
            && point.x >= HistoryPanelLayout.headerDragInset
    }

    private func rememberPosition() {
        guard isVisible, let screen else {
            return
        }

        let visibleFrame = screen.visibleFrame

        positionOffset = CGSize(
            width: frame.midX - visibleFrame.midX,
            height: frame.midY - visibleFrame.midY
        )
        savePositionOffset()
    }

    private func resetPosition() {
        positionOffset = .zero
        savePositionOffset()
        positionOnPointerScreen()
    }

    private static func loadPositionOffset() -> CGSize {
        guard let values = UserDefaults.standard.array(
            forKey: positionOffsetKey
        ) as? [Double],
              values.count == 2 else {
            return .zero
        }

        return CGSize(width: values[0], height: values[1])
    }

    private func savePositionOffset() {
        UserDefaults.standard.set(
            [
                Double(positionOffset.width),
                Double(positionOffset.height)
            ],
            forKey: Self.positionOffsetKey
        )
    }

    private func isUndoDeleteShortcut(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])

        return !event.isARepeat
            && modifiers == [.command]
            && event.charactersIgnoringModifiers?.lowercased() == "z"
    }

    func show() {
        guard !isVisible else {
            makeKey()
            requestSearchFocus()
            return
        }

        viewState.noteShown()
        positionOnPointerScreen()
        makeKeyAndOrderFront(nil)
        requestSearchFocus()
    }

    func hide() {
        rememberPosition()
        orderOut(nil)

        // 下一次打开时回到干净的初始状态：
        // 清空搜索、回到“历史”分区、选中第一条并滚动到顶部。
        viewState.prepareForNextPresentation()
    }

    /// 清空全部历史时调用，避免清空后还能通过 ⌘Z 把旧记录恢复回来。
    func clearUndoHistory() {
        viewState.clearUndoHistory()
    }

    func toggle() {
        if isVisible {
            hide()
            return
        }

        let elapsed = Date().timeIntervalSince(lastResignHideDate)
        guard elapsed > Self.reopenSuppressionInterval else {
            return
        }

        show()
    }

    override func resignKey() {
        super.resignKey()

        guard isVisible else {
            return
        }

        lastResignHideDate = Date()
        hide()
    }

    // MARK: - Undo delete

    /// 恢复最近一次删除的记录。没有可恢复的记录时返回 false。
    @discardableResult
    private func performUndoDelete() -> Bool {
        guard let snapshot = viewState.popUndoSnapshot() else {
            return false
        }

        guard onRestore(snapshot) else {
            // 恢复失败，把副本放回去，让用户还能再试一次。
            viewState.offerUndo(for: snapshot)
            viewState.showNotice("恢复失败：记录可能已被清理。")
            return false
        }

        return true
    }

    // MARK: - Configuration

    private func configureWindow() {
        title = "剪贴板历史"
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // 拖动由标题栏区域自己处理（见 isInDragRegion），不依赖窗口背景拖动。
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]
    }

    private func configureContent(store: HistoryStore) {
        let rootView = HistoryPanelContentView(
            viewState: viewState,
            preferences: preferences,
            onDelete: { [weak self] item in
                guard let self,
                      let snapshot = self.onDelete(item) else {
                    return
                }

                self.viewState.offerUndo(for: snapshot)
            },
            onUndoDelete: { [weak self] in
                self?.performUndoDelete()
            },
            onTogglePin: onTogglePin,
            onToggleFavorite: onToggleFavorite,
            onChoose: onChoose,
            onClose: { [weak self] in
                self?.hide()
            }
        )
        .environment(store)

        contentView = NSHostingView(rootView: rootView)
    }

    private func positionOnPointerScreen() {
        let screens = NSScreen.screens
        let pointerLocation = NSEvent.mouseLocation
        let screenIndex = HistoryPanelPlacement.screenIndex(
            containing: pointerLocation,
            screenFrames: screens.map(\.frame)
        )
        let targetScreen = screenIndex.map { screens[$0] }
            ?? NSScreen.main
            ?? screens.first

        guard let targetScreen else {
            center()
            return
        }

        let targetFrame = HistoryPanelPlacement.frame(
            panelSize: Self.panelSize,
            visibleFrame: targetScreen.visibleFrame,
            offset: positionOffset
        )

        setFrame(targetFrame, display: false)
    }

    private func requestSearchFocus() {
        Task { @MainActor [weak self] in
            await Task.yield()

            guard let self, self.isVisible else {
                return
            }

            self.viewState.requestSearchFocus()
        }
    }
}
