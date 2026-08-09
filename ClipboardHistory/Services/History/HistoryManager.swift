//
//  HistoryManager.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//


import Foundation
import SwiftData

@MainActor
final class HistoryManager {

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
            print("HistoryManager 添加记录失败：\(error)")
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
            print("HistoryManager 获取全部记录失败：\(error)")
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
            print("HistoryManager 获取固定记录失败：\(error)")
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
            print("HistoryManager 删除记录失败：\(error)")
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
            print("HistoryManager 清空记录失败：\(error)")
        }
    }

    // MARK: - Pin

    func setPinned(
        _ isPinned: Bool,
        for item: HistoryItem
    ) {
        do {
            item.isPinned = isPinned
            try modelContext.save()
        } catch {
            print("HistoryManager 修改固定状态失败：\(error)")
        }
    }

    func togglePinned(for item: HistoryItem) {
        setPinned(!item.isPinned, for: item)
    }

    // MARK: - Cleanup

    func debugPrintAll(limit: Int = 20) {
        let items = fetchAll()

        print("========== 剪贴板历史 ==========")
        print("总记录数：\(items.count)")

        guard !items.isEmpty else {
            print("当前没有历史记录")
            print("===============================")
            return
        }

        for (index, item) in items.prefix(limit).enumerated() {
            let preview: String

            switch item.type {
            case .text, .rtf:
                preview = item.textContent?
                    .replacingOccurrences(of: "\n", with: " ")
                    .prefix(60)
                    .description ?? "无法解析文本"

            case .image:
                preview = "图片，\(item.contentData.count) bytes"

            case .fileURL:
                preview = item.fileURL?.lastPathComponent ?? "无法解析文件"

            case .unknown:
                preview = "未知内容，\(item.contentData.count) bytes"
            }

            print(
                """
                [\(index + 1)]
                类型：\(item.type.rawValue)
                内容：\(preview)
                来源：\(item.sourceAppName)
                时间：\(item.timestamp)
                固定：\(item.isPinned)
                Hash：\(item.contentHash)
                """
            )
        }

        if items.count > limit {
            print("仅显示前 \(limit) 条记录")
        }

        print("===============================")
    }

    func cleanupIfNeeded() {
        let itemLimit = maximumUnpinnedItemCount()

        guard itemLimit >= 0 else {
            return
        }

        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate<HistoryItem> { item in
                item.isPinned == false
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

            print("HistoryManager 已清理 \(excessItems.count) 条旧记录")
        } catch {
            print("HistoryManager 自动清理失败：\(error)")
        }
    }
}
