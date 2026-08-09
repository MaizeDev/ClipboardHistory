//
//  HistoryRelativeTimeFormatter.swift
//  ClipboardHistory
//

import Foundation

enum HistoryRelativeTimeFormatter {

    private static let day: TimeInterval = 24 * 60 * 60

    static func string(
        from date: Date,
        relativeTo referenceDate: Date
    ) -> String {
        let elapsed = max(0, referenceDate.timeIntervalSince(date))

        if elapsed < 60 {
            return "刚刚"
        }

        if elapsed < 60 * 60 {
            return "\(Int(elapsed / 60)) 分钟前"
        }

        if elapsed < day {
            return "\(Int(elapsed / (60 * 60))) 小时前"
        }

        if elapsed < 7 * day {
            return "\(Int(elapsed / day)) 天前"
        }

        return date.formatted(
            Calendar.current.isDate(
                date,
                equalTo: referenceDate,
                toGranularity: .year
            )
                ? .dateTime.month().day()
                : .dateTime.year().month().day()
        )
    }
}
