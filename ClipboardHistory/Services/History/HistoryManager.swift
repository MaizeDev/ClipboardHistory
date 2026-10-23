//
//  HistoryManager.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//


import Foundation
import OSLog
import SwiftData

private let historyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
    category: "History"
)

/// 负责修改数据库（增、删、固定、收藏、清理）。
///
/// 每次修改成功后，会同步更新 `store` 里的轻量记录列表，
/// 界面只观察 `store`，不直接接触数据库里的对象。
@MainActor
final class HistoryManager {

    static let maximumPinnedItemCount = 3

    enum AddResult {
        case inserted(HistoryItem)
        case updatedExisting(HistoryItem)
        case failed
    }

    // MARK: - Properties

    /// 界面读取历史记录的数据来源。
    let store: HistoryStore

    private let modelContext: ModelContext
    private let maximumUnpinnedItemCount: () -> Int
    private let retentionDays: () -> Int

    // MARK: - Initialization

    init(
        modelContainer: ModelContainer,
        maximumUnpinnedItemCount: @escaping () -> Int = { 1_000 },
        retentionDays: @escaping () -> Int = { 0 }
    ) {
        let context = modelContainer.mainContext

        self.modelContext = context
        self.maximumUnpinnedItemCount = maximumUnpinnedItemCount
        self.retentionDays = retentionDays
        self.store = HistoryStore(modelContext: context)

        normalizePinnedItems()
        store.reload()
    }

    // MARK: - Add

    @discardableResult
    func add(capture: ClipboardCapture) -> AddResult {
        do {
            if let existingItem = try fetchItem(
                contentHash: capture.contentHash
            ) {
                existingItem.timestamp = capture.capturedAt
                existingItem.sourceAppName = capture.sourceAppName
                existingItem.sourceBundleID = capture.sourceBundleID

                // 再次复制同样的内容时，用这次的附加格式覆盖旧快照。
                // 否则从另一个应用复制相同文字时，粘贴出来还是上一次的格式。
                if existingItem.formatsData != capture.formatsData {
                    existingItem.formatsData = capture.formatsData
                }

                try modelContext.save()
                store.upsert(existingItem)

                return .updatedExisting(existingItem)
            }

            let item = HistoryItem(
                contentData: capture.contentData,
                contentType: capture.contentType,
                timestamp: capture.capturedAt,
                sourceAppName: capture.sourceAppName,
                sourceBundleID: capture.sourceBundleID,
                contentHash: capture.contentHash,
                formatsData: capture.formatsData
            )

            modelContext.insert(item)
            try modelContext.save()
            store.upsert(item)

            cleanupIfNeeded()

            return .inserted(item)
        } catch {
            historyLogger.error(
                "添加剪贴板记录失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
            return .failed
        }
    }

    // MARK: - Fetch

    func fetchItem(contentHash: String) throws -> HistoryItem? {
        let hash = contentHash

        var descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate<HistoryItem> { item in
                item.contentHash == hash
            }
        )

        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    // MARK: - Delete

    /// 删除一条记录。
    /// 成功时返回删除前的完整副本，调用方可以用它来“撤销删除”；失败时返回 nil。
    @discardableResult
    func delete(id: UUID) -> HistoryItemSnapshot? {
        guard let item = store.item(id: id) else {
            // 数据库里已经没有这条记录了，只需要让界面同步。
            store.remove(ids: [id])
            return nil
        }

        let snapshot = HistoryItemSnapshot(item: item)

        do {
            modelContext.delete(item)
            try modelContext.save()
            store.remove(ids: [id])

            return snapshot
        } catch {
            historyLogger.error(
                "删除剪贴板记录失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
            return nil
        }
    }

    func deleteAll() {
        do {
            let items = try modelContext.fetch(
                FetchDescriptor<HistoryItem>()
            )

            for item in items {
                modelContext.delete(item)
            }

            try modelContext.save()
            store.removeAll()
        } catch {
            historyLogger.error(
                "清空剪贴板历史失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
        }
    }

    // MARK: - Restore

    /// 用删除前的副本恢复一条记录。
    @discardableResult
    func restore(snapshot: HistoryItemSnapshot) -> Bool {
        do {
            var changedPinnedIDs: [UUID] = []

            // 删除之后如果又复制了同样的内容，库里已经有一条相同哈希的记录了。
            // 这时不再重复创建，只把删除前的状态合并回去。
            if let existingItem = try fetchItem(
                contentHash: snapshot.contentHash
            ) {
                if snapshot.isFavorite && !existingItem.isFavorite {
                    existingItem.isFavorite = true
                    existingItem.favoritedAt = snapshot.favoritedAt ?? .now
                }

                if snapshot.isPinned && !existingItem.isPinned {
                    changedPinnedIDs += try trimPinnedItems(
                        keeping: Self.maximumPinnedItemCount - 1
                    )
                    existingItem.isPinned = true
                    existingItem.pinnedAt = snapshot.pinnedAt ?? .now
                }

                try modelContext.save()

                store.refresh(ids: changedPinnedIDs)
                store.upsert(existingItem)

                return true
            }

            if snapshot.isPinned {
                changedPinnedIDs = try trimPinnedItems(
                    keeping: Self.maximumPinnedItemCount - 1
                )
            }

            let item = snapshot.makeItem()

            modelContext.insert(item)
            try modelContext.save()

            store.refresh(ids: changedPinnedIDs)
            store.upsert(item)

            return true
        } catch {
            historyLogger.error(
                "恢复剪贴板记录失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
            return false
        }
    }

    // MARK: - Pin

    func setPinned(
        _ isPinned: Bool,
        id: UUID
    ) {
        guard let item = store.item(id: id) else {
            return
        }

        do {
            var changedIDs = [id]

            if isPinned && !item.isPinned {
                changedIDs += try trimPinnedItems(
                    keeping: Self.maximumPinnedItemCount - 1
                )
            }

            item.isPinned = isPinned
            item.pinnedAt = isPinned ? .now : nil
            try modelContext.save()

            store.refresh(ids: changedIDs)
        } catch {
            historyLogger.error(
                "修改固定状态失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
        }
    }

    func togglePinned(id: UUID) {
        guard let item = store.item(id: id) else {
            return
        }

        setPinned(!item.isPinned, id: id)
    }

    // MARK: - Favorite

    func setFavorite(
        _ isFavorite: Bool,
        id: UUID
    ) {
        guard let item = store.item(id: id) else {
            return
        }

        do {
            item.isFavorite = isFavorite
            item.favoritedAt = isFavorite ? .now : nil
            try modelContext.save()

            store.refresh(ids: [id])
        } catch {
            historyLogger.error(
                "修改收藏状态失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
        }
    }

    func toggleFavorite(id: UUID) {
        guard let item = store.item(id: id) else {
            return
        }

        setFavorite(!item.isFavorite, id: id)
    }

    // MARK: - Cleanup

    /// “自动删除超过 N 天的记录”的分界时间。早于它的普通记录会被删除。
    /// 设置页统计“将删除多少条”时也用这个方法，保证两边一致。
    static func retentionCutoff(
        days: Int,
        now: Date = .now
    ) -> Date {
        now.addingTimeInterval(-Double(days) * 24 * 60 * 60)
    }

    /// 清理多余和过期的普通记录（固定和收藏的永远不会被清理）。
    func cleanupIfNeeded() {
        removeExpiredItems()
        removeItemsOverLimit()
    }

    private func removeExpiredItems() {
        let days = retentionDays()

        guard days > 0 else {
            return
        }

        let cutoff = Self.retentionCutoff(days: days)

        let predicate = #Predicate<HistoryItem> { item in
            item.isPinned == false
                && item.isFavorite == false
                && item.timestamp < cutoff
        }

        do {
            let expiredItems = try modelContext.fetch(
                FetchDescriptor<HistoryItem>(predicate: predicate)
            )

            guard !expiredItems.isEmpty else {
                return
            }

            let deletedIDs = Set(expiredItems.map(\.id))

            for item in expiredItems {
                modelContext.delete(item)
            }

            try modelContext.save()
            store.remove(ids: deletedIDs)
        } catch {
            historyLogger.error(
                "删除过期记录失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
        }
    }

    private func removeItemsOverLimit() {
        let itemLimit = maximumUnpinnedItemCount()

        guard itemLimit >= 0 else {
            return
        }

        let predicate = #Predicate<HistoryItem> { item in
            item.isPinned == false && item.isFavorite == false
        }

        do {
            // 先只数一下有多少条。没超过上限就直接结束，不需要把记录取出来。
            let totalCount = try modelContext.fetchCount(
                FetchDescriptor<HistoryItem>(predicate: predicate)
            )

            guard totalCount > itemLimit else {
                return
            }

            // 超过上限时，只取出最旧的那几条（多出来的部分）。
            var oldestDescriptor = FetchDescriptor<HistoryItem>(
                predicate: predicate,
                sortBy: [
                    SortDescriptor(
                        \HistoryItem.timestamp,
                        order: .forward
                    )
                ]
            )
            oldestDescriptor.fetchLimit = totalCount - itemLimit

            let excessItems = try modelContext.fetch(oldestDescriptor)
            let deletedIDs = Set(excessItems.map(\.id))

            for item in excessItems {
                modelContext.delete(item)
            }

            try modelContext.save()
            store.remove(ids: deletedIDs)
        } catch {
            historyLogger.error(
                "自动清理历史失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
        }
    }

    private func normalizePinnedItems() {
        do {
            let changedIDs = try trimPinnedItems(
                keeping: Self.maximumPinnedItemCount
            )

            if !changedIDs.isEmpty {
                try modelContext.save()
            }
        } catch {
            historyLogger.error(
                "整理固定记录失败：\(error.localizedDescription, privacy: .public)"
            )
            modelContext.rollback()
        }
    }

    /// 把固定记录裁剪到最多 `maximumCount` 条（取消最早固定的）。
    /// 返回被取消固定的记录 id，调用方据此刷新界面。
    @discardableResult
    private func trimPinnedItems(keeping maximumCount: Int) throws -> [UUID] {
        let pinnedItems = try modelContext.fetch(
            FetchDescriptor<HistoryItem>(
                predicate: #Predicate<HistoryItem> { item in
                    item.isPinned == true
                }
            )
        )
        .sorted {
            ($0.pinnedAt ?? $0.timestamp) <
                ($1.pinnedAt ?? $1.timestamp)
        }

        let itemsToUnpin = pinnedItems.prefix(
            max(0, pinnedItems.count - maximumCount)
        )

        for pinnedItem in itemsToUnpin {
            pinnedItem.isPinned = false
            pinnedItem.pinnedAt = nil
        }

        return itemsToUnpin.map(\.id)
    }
}
