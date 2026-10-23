//
//  HistoryListView.swift
//  ClipboardHistory
//

import SwiftUI

struct HistoryListView: View {

    @Environment(HistoryStore.self)
    private var store

    @State
    private var selectedItemID: UUID?

    /// 用户还没有手动操作（方向键、点击、固定、收藏、删除）时为 true。
    /// 此时选中项始终跟随列表最上面一条：
    /// 刚复制完就打开面板、新内容稍后才被记录进来，也会自动选中最新的一条。
    /// 一旦用户开始操作，就保持用户自己的选择。
    @State
    private var followsTopItem = true

    /// 最近一次点击星标 / 图钉按钮的时间。
    /// 卡片整体有“双击复制并关闭”的手势，它会和按钮上的快速连点同时被识别，
    /// 所以按钮被点击后的一小段时间内，要忽略卡片上的双击。
    @State
    private var lastButtonInteractionDate = Date.distantPast

    /// 已经完成、并且和当前搜索框内容对应的匹配结果。
    /// 搜索在后台分片进行，结果没回来之前先展示原列表，避免界面卡住或闪空。
    @State
    private var completedSearch: CompletedSearch?

    @State
    private var searchMatchIDs: Set<UUID>?

    /// 列表数据变化时加一，让搜索重新计算匹配结果。
    @State
    private var searchRevision = 0

    private static let buttonInteractionGrace: TimeInterval = 0.6

    /// 搜索输入：搜索词、分区和列表版本。
    /// 任何一项变化都会取消上一次搜索，重新开始。
    private struct SearchInput: Equatable {
        let query: String
        let section: HistoryPanelSection
        let revision: Int
    }

    /// 已经完成的搜索。
    private struct CompletedSearch: Equatable {
        let query: String
        let section: HistoryPanelSection
    }

    let searchText: String
    let section: HistoryPanelSection
    let commandRequest: HistoryPanelCommandRequest?
    let defaultCopyMode: ClipboardCopyMode
    let onDelete: (HistoryRow) -> Void
    let onTogglePin: (HistoryRow) -> Void
    let onToggleFavorite: (HistoryRow) -> Void
    let onChoose: (HistoryRow, ClipboardCopyMode) -> Bool
    let onCopyFailure: (HistoryRow) -> Void
    let onClose: () -> Void
    let isListFocused: Bool
    let onFocusList: () -> Void

    init(
        searchText: String,
        section: HistoryPanelSection,
        commandRequest: HistoryPanelCommandRequest?,
        defaultCopyMode: ClipboardCopyMode,
        onDelete: @escaping (HistoryRow) -> Void,
        onTogglePin: @escaping (HistoryRow) -> Void,
        onToggleFavorite: @escaping (HistoryRow) -> Void,
        onChoose: @escaping (HistoryRow, ClipboardCopyMode) -> Bool,
        onCopyFailure: @escaping (HistoryRow) -> Void,
        onClose: @escaping () -> Void,
        isListFocused: Bool,
        onFocusList: @escaping () -> Void
    ) {
        self.searchText = searchText
        self.section = section
        self.commandRequest = commandRequest
        self.defaultCopyMode = defaultCopyMode
        self.onDelete = onDelete
        self.onTogglePin = onTogglePin
        self.onToggleFavorite = onToggleFavorite
        self.onChoose = onChoose
        self.onCopyFailure = onCopyFailure
        self.onClose = onClose
        self.isListFocused = isListFocused
        self.onFocusList = onFocusList
    }

    var body: some View {
        // 每次刷新只过滤、排序一次，后面所有用到的地方共用这份结果。
        let scoped = scopedItems
        let visibleItems = visibleItems(from: scoped)
        let visibleIDs = visibleItems.map(\.id)

        Group {
            if scoped.isEmpty {
                noHistoryState
            } else if visibleItems.isEmpty {
                noSearchResultsState
            } else {
                historyCards(visibleItems, visibleIDs: visibleIDs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            reconcileSelection(in: visibleIDs)
        }
        .onChange(of: visibleIDs) {
            reconcileSelection(in: visibleIDs)
        }
        .onChange(of: searchText) {
            // 搜索词变化（输入或清空）后，高亮回到第一条结果。
            followsTopItem = true
            reconcileSelection(in: visibleIDs)
        }
        .onChange(of: section) {
            // 切换“历史/收藏”后，同样回到第一条。
            followsTopItem = true
            reconcileSelection(in: visibleIDs)
        }
        .onChange(of: isListFocused) {
            // 进入列表焦点后，选中项固定下来，不再自动跟随最上面一条。
            if isListFocused {
                followsTopItem = false
            }
        }
        .onChange(of: commandRequest) {
            guard let commandRequest else {
                return
            }

            handle(commandRequest.command, items: visibleItems)
        }
        .onChange(of: store.rows) {
            searchRevision &+= 1
        }
        .task(id: SearchInput(
            query: normalizedSearchQuery,
            section: section,
            revision: searchRevision
        )) {
            await updateSearchMatches()
        }
    }

    private func historyCards(
        _ visibleItems: [HistoryRow],
        visibleIDs: [UUID]
    ) -> some View {
        // 固定每分钟刷新一次相对时间，避免每次列表重绘都新建一个从 `.now`
        // 开始的定时计划，导致“1 分钟前”之类的文字偶尔不刷新。
        TimelineView(.everyMinute) { context in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleItems) { item in
                            HistoryItemCard(
                                item: item,
                                isSelected: selectedItemID == item.id,
                                isListFocused: isListFocused,
                                referenceDate: context.date,
                                onTogglePin: {
                                    noteButtonInteraction()
                                    followsTopItem = false
                                    onFocusList()
                                    onTogglePin(item)
                                },
                                onToggleFavorite: {
                                    noteButtonInteraction()
                                    followsTopItem = false
                                    onFocusList()
                                    onToggleFavorite(item)
                                },
                                onCopyOriginal: {
                                    choose(item, mode: .original)
                                },
                                onCopyPlainText: {
                                    choose(item, mode: .plainText)
                                }
                            )
                            .onTapGesture {
                                followsTopItem = false
                                selectedItemID = item.id
                                onFocusList()
                            }
                            .simultaneousGesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        guard !isRecentButtonInteraction else {
                                            return
                                        }

                                        followsTopItem = false
                                        selectedItemID = item.id
                                        choose(item, mode: defaultCopyMode)
                                    }
                            )
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

                    // 方向键移动选中项时，只滚动到“刚好可见”，
                    // 不再每次都把选中项强行滚到屏幕中央，列表不会来回跳。
                    proxy.scrollTo(selectedItemID)
                }
                .onChange(of: visibleIDs) {
                    guard followsTopItem,
                          let selectedItemID else {
                        return
                    }

                    proxy.scrollTo(selectedItemID, anchor: .top)
                }
            }
        }
    }

    // MARK: - Items

    private var scopedItems: [HistoryRow] {
        scopedItems(for: section)
    }

    private func scopedItems(for section: HistoryPanelSection) -> [HistoryRow] {
        switch section {
        case .history:
            store.rows
        case .favorites:
            store.rows.filter(\.isFavorite)
        }
    }

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentSearchKey: CompletedSearch? {
        let query = normalizedSearchQuery

        guard !query.isEmpty else {
            return nil
        }

        return CompletedSearch(query: query, section: section)
    }

    private func visibleItems(from scoped: [HistoryRow]) -> [HistoryRow] {
        let matched: [HistoryRow]

        if normalizedSearchQuery.isEmpty {
            matched = scoped
        } else if completedSearch == currentSearchKey, let searchMatchIDs {
            matched = scoped.filter { searchMatchIDs.contains($0.id) }
        } else {
            // 搜索还没算完（或者刚切换了输入），先展示原列表，
            // 结果回来后再收窄，避免每次按键都把列表清空。
            matched = scoped
        }

        if section == .favorites {
            return matched.sorted { lhs, rhs in
                (lhs.favoritedAt ?? lhs.timestamp) >
                    (rhs.favoritedAt ?? rhs.timestamp)
            }
        }

        // 列表数据已经按时间从新到旧排好了，
        // 这里只需要把固定的记录提到最前面，不必整体重新排序。
        let pinned = matched
            .filter(\.isPinned)
            .sorted { $0.timestamp > $1.timestamp }

        guard !pinned.isEmpty else {
            return matched
        }

        return pinned + matched.filter { !$0.isPinned }
    }

    // MARK: - Search

    /// 防抖后在主线程分片计算搜索结果。
    /// 每条记录都可能要读取外部存储中的完整内容，一次算完会卡住界面；
    /// 这里每处理一小批就让出一次主线程，并在任务取消时立即退出。
    private func updateSearchMatches() async {
        let query = normalizedSearchQuery
        let targetSection = section

        guard !query.isEmpty else {
            searchMatchIDs = nil
            completedSearch = nil
            return
        }

        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else {
            return
        }

        let rows = scopedItems(for: targetSection)
        var matched: Set<UUID> = []
        matched.reserveCapacity(rows.count / 4)

        for (index, row) in rows.enumerated() {
            if Task.isCancelled {
                return
            }

            if HistorySearch.matches(
                row,
                query: query,
                fullText: { store.fullText(for: $0) }
            ) {
                matched.insert(row.id)
            }

            if index.isMultiple(of: 32) {
                await Task.yield()
            }
        }

        guard !Task.isCancelled else {
            return
        }

        searchMatchIDs = matched
        completedSearch = CompletedSearch(
            query: query,
            section: targetSection
        )
    }

    // MARK: - Selection

    private func noteButtonInteraction() {
        lastButtonInteractionDate = Date()
    }

    private var isRecentButtonInteraction: Bool {
        Date().timeIntervalSince(lastButtonInteractionDate)
            < Self.buttonInteractionGrace
    }

    private func reconcileSelection(in itemIDs: [UUID]) {
        if followsTopItem {
            selectedItemID = itemIDs.first
            return
        }

        selectedItemID = HistorySelection.reconciled(
            selectedItemID,
            in: itemIDs
        )
    }

    private func handle(
        _ command: HistoryPanelCommand,
        items: [HistoryRow]
    ) {
        followsTopItem = false

        let itemIDs = items.map(\.id)
        let selectedItem = items.first { item in
            item.id == selectedItemID
        }

        switch command {
        case .moveSelection(let offset):
            selectedItemID = HistorySelection.moving(
                from: selectedItemID,
                offset: offset,
                in: itemIDs
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
                in: itemIDs
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
                from: itemIDs
            )
            onDelete(selectedItem)

        case .togglePin:
            guard let selectedItem else {
                return
            }

            onTogglePin(selectedItem)

        case .toggleFavorite:
            guard let selectedItem else {
                return
            }

            onToggleFavorite(selectedItem)

        case .dismiss:
            onClose()
        }
    }

    private func choose(_ item: HistoryRow, mode: ClipboardCopyMode) {
        guard onChoose(item, mode) else {
            onCopyFailure(item)
            return
        }

        onClose()
    }

    private func alternativeMode(for item: HistoryRow) -> ClipboardCopyMode {
        guard item.supportsPlainText else {
            return .original
        }

        return defaultCopyMode.alternative
    }

    // MARK: - Empty states

    private var noHistoryState: some View {
        ContentUnavailableView {
            Label(emptyStateTitle, systemImage: section.systemImage)
        } description: {
            Text(emptyStateDescription)
        }
    }

    private var emptyStateTitle: String {
        switch section {
        case .history:
            "还没有剪贴板记录"
        case .favorites:
            "还没有收藏"
        }
    }

    private var emptyStateDescription: String {
        switch section {
        case .history:
            "复制过的内容会以卡片显示在这里"
        case .favorites:
            "点击卡片上的星标，把重要内容长期保存在这里"
        }
    }

    private var noSearchResultsState: some View {
        ContentUnavailableView.search(text: searchText)
    }
}
