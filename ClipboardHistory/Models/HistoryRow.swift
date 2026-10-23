//
//  HistoryRow.swift
//  ClipboardHistory
//

import Foundation

/// 一条历史记录在界面上用到的轻量副本。
///
/// 界面（列表、卡片）只读取它，不再直接持有 SwiftData 的 `HistoryItem`：
/// - 记录被删除后，界面里不会残留指向“已失效对象”的引用；
/// - 它不包含图片、文字等大数据，列表常驻内存的开销很小；
/// - 界面和数据库解耦之后，以后重新设计界面也不会碰到数据层。
///
/// 需要文字预览、缩略图或者执行操作时，用 `id` 到 `HistoryStore` 里按需取回。
struct HistoryRow: Identifiable, Equatable, Sendable {

    let id: UUID
    let type: ClipboardContentType
    let timestamp: Date
    let sourceAppName: String
    let sourceBundleID: String
    let isPinned: Bool
    let pinnedAt: Date?
    let isFavorite: Bool
    let favoritedAt: Date?
    let contentHash: String

    /// 文件类型记录里的所有文件。其他类型为空数组。
    let fileURLs: [URL]

    init(item: HistoryItem) {
        id = item.id
        type = item.type
        timestamp = item.timestamp
        sourceAppName = item.sourceAppName
        sourceBundleID = item.sourceBundleID
        isPinned = item.isPinned
        pinnedAt = item.pinnedAt
        isFavorite = item.isFavorite
        favoritedAt = item.favoritedAt
        contentHash = item.contentHash
        fileURLs = item.fileURLs
    }

    /// 第一个文件。
    var fileURL: URL? {
        fileURLs.first
    }

    /// 只有文字和富文本才能“纯文本复制”。
    var supportsPlainText: Bool {
        type == .text || type == .rtf
    }
}
