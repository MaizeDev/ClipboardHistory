//
//  HistorySearch.swift
//  ClipboardHistory
//

import Foundation

@MainActor
enum HistorySearch {

    /// 一次过滤整个列表。
    /// 搜索词只在开头整理一次；搜索词为空时直接返回原列表，不读取任何记录内容。
    ///
    /// - Parameter fullText: 取一条记录的完整文字（需要时才会调用，调用方负责缓存）。
    static func filter(
        _ rows: [HistoryRow],
        query: String,
        fullText: (HistoryRow) -> String?
    ) -> [HistoryRow] {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            return rows
        }

        return rows.filter { row in
            matches(row, query: trimmedQuery, fullText: fullText)
        }
    }

    /// 单条记录是否命中搜索词。`query` 需要是调用方已经去掉首尾空白的文本。
    /// 搜索会逐条读取完整内容，可能很慢；调用方应当分片调用并允许取消，
    /// 不要把一次搜索的全部工作都压在一个主线程循环里。
    static func matches(
        _ row: HistoryRow,
        query: String,
        fullText: (HistoryRow) -> String?
    ) -> Bool {
        searchableValues(for: row, fullText: fullText).contains { value in
            value.localizedCaseInsensitiveContains(query)
        }
    }

    private static func searchableValues(
        for row: HistoryRow,
        fullText: (HistoryRow) -> String?
    ) -> [String] {
        let fileNames = row.fileURLs
            .map(\.lastPathComponent)
            .joined(separator: " ")

        return [
            fullText(row),
            fileNames,
            row.sourceAppName
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else {
                return nil
            }

            return value
        }
    }
}
