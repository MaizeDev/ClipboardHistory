//
//  HistoryListView.swift
//  ClipboardHistory
//

import SwiftData
import SwiftUI

struct HistoryListView: View {

    @Query(
        sort: \HistoryItem.timestamp,
        order: .reverse
    )
    private var items: [HistoryItem]

    @State
    private var selectedItemID: UUID?

    @State
    private var hoveredItemID: UUID?

    let searchText: String
    let commandRequest: HistoryPanelCommandRequest?
    let defaultCopyMode: ClipboardCopyMode
    let onDelete: (HistoryItem) -> Void
    let onTogglePin: (HistoryItem) -> Void
    let onChoose: (HistoryItem, ClipboardCopyMode) -> Bool
    let onClose: () -> Void

    init(
        searchText: String,
        commandRequest: HistoryPanelCommandRequest?,
        defaultCopyMode: ClipboardCopyMode,
        onDelete: @escaping (HistoryItem) -> Void,
        onTogglePin: @escaping (HistoryItem) -> Void,
        onChoose: @escaping (HistoryItem, ClipboardCopyMode) -> Bool,
        onClose: @escaping () -> Void
    ) {
        self.searchText = searchText
        self.commandRequest = commandRequest
        self.defaultCopyMode = defaultCopyMode
        self.onDelete = onDelete
        self.onTogglePin = onTogglePin
        self.onChoose = onChoose
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if items.isEmpty {
                noHistoryState
            } else if filteredItems.isEmpty {
                noSearchResultsState
            } else {
                historyCards
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            reconcileSelection()
        }
        .onChange(of: filteredItemIDs) {
            reconcileSelection()
        }
        .onChange(of: commandRequest) {
            guard let commandRequest else {
                return
            }

            handle(commandRequest.command)
        }
    }

    private var historyCards: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            HistoryItemCard(
                                item: item,
                                isSelected: selectedItemID == item.id,
                                referenceDate: context.date,
                                showsCopyActions: shouldShowCopyActions(for: item),
                                onCopyOriginal: {
                                    choose(item, mode: .original)
                                },
                                onCopyPlainText: {
                                    choose(item, mode: .plainText)
                                }
                            )
                            .onTapGesture {
                                selectedItemID = item.id
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        selectedItemID = item.id
                                        choose(item, mode: defaultCopyMode)
                                    }
                            )
                            .onHover { isHovering in
                                if isHovering {
                                    hoveredItemID = item.id
                                } else if hoveredItemID == item.id {
                                    hoveredItemID = nil
                                }
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAddTraits(
                                selectedItemID == item.id ? .isSelected : []
                            )
                            .id(item.id)
                        }
                    }
                    .padding(16)
                }
                .scrollIndicators(.visible)
                .onChange(of: selectedItemID) {
                    guard let selectedItemID else {
                        return
                    }

                    proxy.scrollTo(selectedItemID, anchor: .center)
                }
                .onChange(of: filteredItemIDs) {
                    guard let selectedItemID else {
                        return
                    }

                    proxy.scrollTo(selectedItemID, anchor: .center)
                }
            }
        }
    }

    private var filteredItems: [HistoryItem] {
        items
            .filter { item in
                HistorySearch.matches(item, query: searchText)
            }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                return lhs.timestamp > rhs.timestamp
            }
    }

    private var filteredItemIDs: [UUID] {
        filteredItems.map(\.id)
    }

    private var selectedItem: HistoryItem? {
        guard let selectedItemID else {
            return nil
        }

        return filteredItems.first { item in
            item.id == selectedItemID
        }
    }

    private func reconcileSelection() {
        selectedItemID = HistorySelection.reconciled(
            selectedItemID,
            in: filteredItemIDs
        )
    }

    private func handle(_ command: HistoryPanelCommand) {
        switch command {
        case .moveSelection(let offset):
            selectedItemID = HistorySelection.moving(
                from: selectedItemID,
                offset: offset,
                in: filteredItemIDs
            )

        case .chooseSelection:
            guard let selectedItem else {
                return
            }

            choose(selectedItem, mode: defaultCopyMode)

        case .chooseSelectionAlternative:
            guard let selectedItem else {
                return
            }

            choose(selectedItem, mode: alternativeMode(for: selectedItem))

        case .selectItem(let index):
            guard let itemID = HistorySelection.item(
                at: index,
                in: filteredItemIDs
            ) else {
                return
            }

            selectedItemID = itemID

        case .deleteSelection:
            guard let selectedItem else {
                return
            }

            selectedItemID = HistorySelection.afterRemoving(
                selectedItem.id,
                from: filteredItemIDs
            )
            onDelete(selectedItem)

        case .togglePin:
            guard let selectedItem else {
                return
            }

            onTogglePin(selectedItem)

        case .dismiss:
            onClose()
        }
    }

    private func choose(_ item: HistoryItem, mode: ClipboardCopyMode) {
        guard onChoose(item, mode) else {
            return
        }

        onClose()
    }

    private func shouldShowCopyActions(for item: HistoryItem) -> Bool {
        guard item.type == .text || item.type == .rtf else {
            return false
        }

        return selectedItemID == item.id || hoveredItemID == item.id
    }

    private func alternativeMode(for item: HistoryItem) -> ClipboardCopyMode {
        guard item.type == .text || item.type == .rtf else {
            return .original
        }

        return defaultCopyMode.alternative
    }

    private var noHistoryState: some View {
        ContentUnavailableView {
            Label("还没有剪贴板记录", systemImage: "doc.on.clipboard")
        } description: {
            Text("复制过的内容会以卡片显示在这里")
        }
    }

    private var noSearchResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }
}
