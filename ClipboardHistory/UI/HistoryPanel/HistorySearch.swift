//
//  HistorySearch.swift
//  ClipboardHistory
//

import Foundation

enum HistorySearch {

    static func matches(
        _ item: HistoryItem,
        query: String
    ) -> Bool {
        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            return true
        }

        return searchableValues(for: item).contains { value in
            value.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private static func searchableValues(
        for item: HistoryItem
    ) -> [String] {
        [
            item.textContent,
            item.fileURL?.lastPathComponent,
            item.sourceAppName,
            item.sourceBundleID
        ]
        .compactMap { value in
            guard let value, !value.isEmpty else {
                return nil
            }

            return value
        }
    }
}
