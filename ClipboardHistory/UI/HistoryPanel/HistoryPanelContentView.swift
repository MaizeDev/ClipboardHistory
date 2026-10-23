//
//  HistoryPanelContentView.swift
//  ClipboardHistory
//

import SwiftData
import SwiftUI

enum HistoryPanelLayout {
    static let width: CGFloat = 460
    static let height: CGFloat = 560

    /// 顶部标题栏的高度。这一块同时是拖动浮窗的区域。
    static let headerHeight: CGFloat = 58

    /// 标题栏左侧关闭按钮占用的宽度，这一段不作为拖动区域。
    static let headerDragInset: CGFloat = 56
}

struct HistoryPanelContentView: View {

    @Bindable var viewState: HistoryPanelViewState

    let preferences: AppPreferences
    let onDelete: (HistoryRow) -> Void
    let onUndoDelete: () -> Void
    let onTogglePin: (HistoryRow) -> Void
    let onToggleFavorite: (HistoryRow) -> Void
    let onChoose: (HistoryRow, ClipboardCopyMode) -> Bool
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("显示内容", selection: $viewState.selectedSection) {
                ForEach(HistoryPanelSection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            SearchBar(
                text: $viewState.searchText,
                focusRequest: viewState.searchFocusRequest
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.45)

            HistoryListView(
                searchText: viewState.searchText,
                section: viewState.selectedSection,
                commandRequest: viewState.commandRequest,
                defaultCopyMode: preferences.defaultCopyMode,
                onDelete: onDelete,
                onTogglePin: onTogglePin,
                onToggleFavorite: onToggleFavorite,
                onChoose: onChoose,
                onCopyFailure: { item in
                    viewState.showNotice(copyFailureMessage(for: item))
                },
                onClose: onClose,
                isListFocused: viewState.isListFocused,
                onFocusList: { viewState.focusList() }
            )
            .id(viewState.presentationID)
            .environment(viewState)
        }
        .frame(
            width: HistoryPanelLayout.width,
            height: HistoryPanelLayout.height
        )
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let noticeMessage = viewState.noticeMessage {
                    PanelNoticeBanner(message: noticeMessage)
                        .transition(
                            .move(edge: .bottom).combined(with: .opacity)
                        )
                }

                if viewState.undoCount > 0 {
                    UndoDeleteBanner(
                        count: viewState.undoCount,
                        onUndo: onUndoDelete
                    )
                    .transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.25),
            value: viewState.undoCount > 0
        )
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.25),
            value: viewState.noticeMessage
        )
        .background(.regularMaterial)
        .clipShape(.rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.primary.opacity(0.10), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button("关闭剪贴板历史", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.08), in: Circle())
                .buttonStyle(.plain)

            Text("剪贴板历史")
                .font(.title3.weight(.semibold))

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: HistoryPanelLayout.headerHeight)
    }

    /// 复制失败时给用户的提示。文件记录最常见的原因是文件被移动或删除了。
    private func copyFailureMessage(for item: HistoryRow) -> String {
        switch item.type {
        case .fileURL:
            "复制失败：文件可能已被移动或删除。"
        case .image:
            "复制失败：图片内容可能已损坏。"
        case .text, .rtf, .unknown:
            "复制失败：内容可能已失效。"
        }
    }
}

private struct PanelNoticeBanner: View {

    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.primary.opacity(0.12), lineWidth: 1)
            }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: HistoryItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    HistoryPanelContentView(
        viewState: HistoryPanelViewState(),
        preferences: AppPreferences(),
        onDelete: { _ in },
        onUndoDelete: {},
        onTogglePin: { _ in },
        onToggleFavorite: { _ in },
        onChoose: { _, _ in true },
        onClose: {}
    )
    .environment(HistoryStore(modelContext: container.mainContext))
    .padding(40)
}
