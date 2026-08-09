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

@MainActor
final class HistoryManager {

    static let maximumPinnedItemCount = 3

    enum AddResult {
        case inserted(HistoryItem)
        case updatedExisting(HistoryItem)
        case failed
    }

    // MARK: - Properties

    private let modelContext: ModelContext
    private let maximumUnpinnedItemCount: () -> Int

    // MARK: - Initialization

    init(
        modelContainer: ModelContainer,
        maximumUnpinnedItemCount: @escaping () -> Int = { 1_000 }
    ) {
        self.modelContext = modelContainer.mainContext
        self.maximumUnpinnedItemCount = maximumUnpinnedItemCount
        normalizePinnedItems()
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

                try modelContext.save()

                return .updatedExisting(existingItem)
            }

            let item = HistoryItem(
                contentData: capture.contentData,
                contentType: capture.contentType,
                timestamp: capture.capturedAt,
                sourceAppName: capture.sourceAppName,
                sourceBundleID: capture.sourceBundleID,
                contentHash: capture.contentHash
            )

            modelContext.insert(item)
            try modelContext.save()

            cleanupIfNeeded()

            return .inserted(item)
        } catch {
            historyLogger.error(
                "添加剪贴板记录失败：\(error.localizedDescription, privacy: .public)"
            )
            return .failed
        }
    }

    // MARK: - Fetch

    func fetchAll() -> [HistoryItem] {
        var descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [
                SortDescriptor(
                    \HistoryItem.timestamp,
                    order: .reverse
                )
            ]
        )

        descriptor.includePendingChanges = true

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            historyLogger.error(
                "读取剪贴板历史失败：\(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    func fetchPinned() -> [HistoryItem] {
        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate<HistoryItem> { item in
                item.isPinned == true
            },
            sortBy: [
                SortDescriptor(
                    \HistoryItem.timestamp,
                    order: .reverse
                )
            ]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            historyLogger.error(
                "读取固定记录失败：\(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

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

    func delete(item: HistoryItem) {
        do {
            modelContext.delete(item)
            try modelContext.save()
        } catch {
            historyLogger.error(
                "删除剪贴板记录失败：\(error.localizedDescription, privacy: .public)"
            )
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
        } catch {
            historyLogger.error(
                "清空剪贴板历史失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Pin

    func setPinned(
        _ isPinned: Bool,
        for item: HistoryItem
    ) {
        do {
            if isPinned && !item.isPinned {
                try trimPinnedItems(
                    keeping: Self.maximumPinnedItemCount - 1
                )
            }

            item.isPinned = isPinned
            item.pinnedAt = isPinned ? .now : nil
            try modelContext.save()
        } catch {
            historyLogger.error(
                "修改固定状态失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func togglePinned(for item: HistoryItem) {
        setPinned(!item.isPinned, for: item)
    }

    // MARK: - Favorite

    func setFavorite(
        _ isFavorite: Bool,
        for item: HistoryItem
    ) {
        do {
            item.isFavorite = isFavorite
            item.favoritedAt = isFavorite ? .now : nil
            try modelContext.save()
        } catch {
            historyLogger.error(
                "修改收藏状态失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func toggleFavorite(for item: HistoryItem) {
        setFavorite(!item.isFavorite, for: item)
    }

    // MARK: - Cleanup

    func cleanupIfNeeded() {
        let itemLimit = maximumUnpinnedItemCount()

        guard itemLimit >= 0 else {
            return
        }

        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate<HistoryItem> { item in
                item.isPinned == false && item.isFavorite == false
            },
            sortBy: [
                SortDescriptor(
                    \HistoryItem.timestamp,
                    order: .reverse
                )
            ]
        )

        do {
            let unpinnedItems = try modelContext.fetch(descriptor)

            guard unpinnedItems.count > itemLimit else {
                return
            }

            let excessItems = unpinnedItems.dropFirst(
                itemLimit
            )

            for item in excessItems {
                modelContext.delete(item)
            }

            try modelContext.save()
        } catch {
            historyLogger.error(
                "自动清理历史失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func normalizePinnedItems() {
        do {
            let didChange = try trimPinnedItems(
                keeping: Self.maximumPinnedItemCount
            )

            if didChange {
                try modelContext.save()
            }
        } catch {
            historyLogger.error(
                "整理固定记录失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    @discardableResult
    private func trimPinnedItems(keeping maximumCount: Int) throws -> Bool {
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

        return !itemsToUnpin.isEmpty
    }
}
