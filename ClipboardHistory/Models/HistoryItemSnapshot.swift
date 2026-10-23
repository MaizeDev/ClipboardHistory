//
//  HistoryItemSnapshot.swift
//  ClipboardHistory
//

import Foundation

/// 一条历史记录的完整副本，用于“撤销删除”。
///
/// SwiftData 的模型对象被删除后就失效了，不能再读取。
/// 所以删除之前先把所有字段复制出来，撤销时再用这份副本重新创建记录。
struct HistoryItemSnapshot: Identifiable {

    let id: UUID
    let contentData: Data
    let contentType: String
    let timestamp: Date
    let sourceAppName: String
    let sourceBundleID: String
    let isPinned: Bool
    let pinnedAt: Date?
    let isFavorite: Bool
    let favoritedAt: Date?
    let contentHash: String
    let formatsData: Data?

    init(item: HistoryItem) {
        id = item.id
        contentData = item.contentData
        contentType = item.contentType
        timestamp = item.timestamp
        sourceAppName = item.sourceAppName
        sourceBundleID = item.sourceBundleID
        isPinned = item.isPinned
        pinnedAt = item.pinnedAt
        isFavorite = item.isFavorite
        favoritedAt = item.favoritedAt
        contentHash = item.contentHash
        formatsData = item.formatsData
    }

    func makeItem() -> HistoryItem {
        HistoryItem(
            id: id,
            contentData: contentData,
            contentType: ClipboardContentType(rawValue: contentType) ?? .unknown,
            timestamp: timestamp,
            sourceAppName: sourceAppName,
            sourceBundleID: sourceBundleID,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            isFavorite: isFavorite,
            favoritedAt: favoritedAt,
            contentHash: contentHash,
            formatsData: formatsData
        )
    }
}
