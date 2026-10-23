//
//  HistoryStore.swift
//  ClipboardHistory
//

import AppKit
import Foundation
import Observation
import OSLog
import SwiftData

private let storeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
    category: "HistoryStore"
)

/// 界面读取历史记录的唯一入口。
///
/// 它持有一份轻量的 `HistoryRow` 列表（按时间从新到旧），
/// 界面只观察这份列表，不再直接使用 SwiftData 的 `@Query` 和 `HistoryItem`。
/// 列表只由 `HistoryManager` 在数据库修改成功之后通过下面的方法更新。
///
/// 需要文字预览、缩略图或原始记录时，才用 `id` 回到数据库里按需读取。
@Observable
@MainActor
final class HistoryStore {

    /// 全部历史记录，按时间从新到旧。
    private(set) var rows: [HistoryRow] = []

    @ObservationIgnored
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Updating rows (called by HistoryManager)

    /// 从数据库重新读取全部记录。只在启动时使用。
    func reload() {
        let descriptor = FetchDescriptor<HistoryItem>(
            sortBy: [
                SortDescriptor(
                    \HistoryItem.timestamp,
                    order: .reverse
                )
            ]
        )

        do {
            rows = try modelContext.fetch(descriptor).map(
                HistoryRow.init(item:)
            )
        } catch {
            storeLogger.error(
                "读取剪贴板历史失败：\(error.localizedDescription, privacy: .public)"
            )
            rows = []
        }
    }

    /// 新增或更新一条记录，并放到按时间排序的正确位置。
    func upsert(_ item: HistoryItem) {
        let row = HistoryRow(item: item)

        rows.removeAll { $0.id == row.id }

        let index = rows.firstIndex { $0.timestamp < row.timestamp }
            ?? rows.endIndex

        rows.insert(row, at: index)
    }

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else {
            return
        }

        rows.removeAll { ids.contains($0.id) }
    }

    func removeAll() {
        rows = []
    }

    /// 重新读取指定记录的状态（比如固定、收藏发生了变化）。时间没变，所以不需要重新排序。
    func refresh(ids: [UUID]) {
        for id in ids {
            guard let index = rows.firstIndex(where: { $0.id == id }) else {
                continue
            }

            if let item = item(id: id) {
                rows[index] = HistoryRow(item: item)
            } else {
                rows.remove(at: index)
            }
        }
    }

    // MARK: - On-demand access

    /// 按 id 取回原始记录。只在需要读取内容或执行操作时使用，不要长期持有。
    func item(id: UUID) -> HistoryItem? {
        let targetID = id

        var descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate<HistoryItem> { item in
                item.id == targetID
            }
        )

        descriptor.fetchLimit = 1

        return try? modelContext.fetch(descriptor).first
    }

    /// 卡片上显示的文字预览。只有文字和富文本有预览。
    func previewText(for row: HistoryRow) -> String? {
        guard row.supportsPlainText else {
            return nil
        }

        return HistoryPreviewCache.shared.previewText(
            forKey: row.contentHash
        ) {
            item(id: row.id)?.textContent
        }
    }

    /// 搜索用的完整文字。文字、富文本和文件类型都有。
    func fullText(for row: HistoryRow) -> String? {
        guard row.type != .image, row.type != .unknown else {
            return nil
        }

        return HistoryPreviewCache.shared.fullText(
            forKey: row.contentHash
        ) {
            item(id: row.id)?.textContent
        }
    }

    /// 只查缓存里已经生成好的缩略图。
    func cachedThumbnail(for row: HistoryRow) -> NSImage? {
        ImageThumbnailService.shared.cachedThumbnail(
            forKey: row.contentHash
        )
    }

    /// 取图片缩略图，没有缓存时在后台生成。
    func thumbnail(for row: HistoryRow) async -> NSImage? {
        if let cached = cachedThumbnail(for: row) {
            return cached
        }

        guard let data = item(id: row.id)?.contentData else {
            return nil
        }

        return await ImageThumbnailService.shared.thumbnail(
            forKey: row.contentHash,
            data: data
        )
    }
}
