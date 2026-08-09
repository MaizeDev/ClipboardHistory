//
//  HistoryPanelContentView.swift
//  ClipboardHistory
//

import SwiftData
import SwiftUI

enum HistoryPanelLayout {
    static let width: CGFloat = 460
    static let height: CGFloat = 560
}

@Observable
@MainActor
final class HistoryPanelViewState {

    private(set) var searchFocusRequest = 0
    private(set) var commandRequest: HistoryPanelCommandRequest?

    private var commandSequence = 0

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
}

struct HistoryPanelCommandRequest: Equatable {
    let sequence: Int
    let command: HistoryPanelCommand
}

struct HistoryPanelContentView: View {

    let viewState: HistoryPanelViewState
    let preferences: AppPreferences
    let onDelete: (HistoryItem) -> Void
    let onTogglePin: (HistoryItem) -> Void
    let onToggleFavorite: (HistoryItem) -> Void
    let onChoose: (HistoryItem, ClipboardCopyMode) -> Bool
    let onClose: () -> Void

    @State
    private var searchText = ""

    @State
    private var selectedSection = HistoryPanelSection.history

    var body: some View {
        VStack(spacing: 0) {
            header

            Picker("显示内容", selection: $selectedSection) {
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
                text: $searchText,
                focusRequest: viewState.searchFocusRequest
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.45)

            HistoryListView(
                searchText: searchText,
                section: selectedSection,
                commandRequest: viewState.commandRequest,
                defaultCopyMode: preferences.defaultCopyMode,
                onDelete: onDelete,
                onTogglePin: onTogglePin,
                onToggleFavorite: onToggleFavorite,
                onChoose: onChoose,
                onClose: onClose
            )
        }
        .frame(
            width: HistoryPanelLayout.width,
            height: HistoryPanelLayout.height
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
        .frame(height: 58)
    }

}

#Preview {
    HistoryPanelContentView(
        viewState: HistoryPanelViewState(),
        preferences: AppPreferences(),
        onDelete: { _ in },
        onTogglePin: { _ in },
        onToggleFavorite: { _ in },
        onChoose: { _, _ in true },
        onClose: {}
    )
        .modelContainer(for: HistoryItem.self, inMemory: true)
        .padding(40)
}
