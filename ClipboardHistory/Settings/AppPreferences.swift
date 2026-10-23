//
//  AppPreferences.swift
//  ClipboardHistory
//

import Foundation
import Observation

struct IgnoredApplication: Codable, Hashable, Identifiable {
    let name: String
    let bundleIdentifier: String
    let path: String

    var id: String {
        bundleIdentifier
    }
}

@Observable
@MainActor
final class AppPreferences {

    static let historyCountOptions = [
        5, 10, 25, 50,
        100, 250, 500, 1_000, 2_000, 5_000
    ]

    /// 自动删除旧记录的天数选项。0 表示永不自动删除。
    static let retentionDayOptions = [0, 1, 7, 30, 90]

    private enum Key {
        static let maximumHistoryCount = "maximumHistoryCount"
        static let ignoredApplications = "ignoredApplications"
        static let defaultCopyMode = "defaultCopyMode"
        static let historyRetentionDays = "historyRetentionDays"
    }

    private static let defaultHistoryCount = 1_000

    var defaultCopyMode: ClipboardCopyMode {
        didSet {
            guard oldValue != defaultCopyMode else {
                return
            }

            defaults.set(defaultCopyMode.rawValue, forKey: Key.defaultCopyMode)
        }
    }

    var maximumHistoryCount: Int {
        didSet {
            guard oldValue != maximumHistoryCount else {
                return
            }

            defaults.set(maximumHistoryCount, forKey: Key.maximumHistoryCount)
            onMaximumHistoryCountChange?()
        }
    }

    /// 超过这么多天的普通记录会被自动删除。0 表示永不删除（默认）。
    var historyRetentionDays: Int {
        didSet {
            guard oldValue != historyRetentionDays else {
                return
            }

            defaults.set(
                historyRetentionDays,
                forKey: Key.historyRetentionDays
            )
            onHistoryRetentionDaysChange?()
        }
    }

    /// 是否暂停记录。只在本次运行期间有效，重新启动后恢复记录，
    /// 避免忘记恢复而一直漏记。
    var isRecordingPaused = false

    private(set) var ignoredApplications: [IgnoredApplication] {
        didSet {
            saveIgnoredApplications()
        }
    }

    @ObservationIgnored
    var onMaximumHistoryCountChange: (() -> Void)?

    @ObservationIgnored
    var onHistoryRetentionDaysChange: (() -> Void)?

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaultCopyMode = ClipboardCopyMode(
            rawValue: defaults.string(forKey: Key.defaultCopyMode) ?? ""
        ) ?? .original

        let storedHistoryCount = defaults.integer(
            forKey: Key.maximumHistoryCount
        )
        maximumHistoryCount = Self.historyCountOptions.contains(
            storedHistoryCount
        ) ? storedHistoryCount : Self.defaultHistoryCount

        let storedRetentionDays = defaults.integer(
            forKey: Key.historyRetentionDays
        )
        historyRetentionDays = Self.retentionDayOptions.contains(
            storedRetentionDays
        ) ? storedRetentionDays : 0

        if let data = defaults.data(forKey: Key.ignoredApplications),
           let applications = try? JSONDecoder().decode(
               [IgnoredApplication].self,
               from: data
           ) {
            ignoredApplications = applications
        } else {
            ignoredApplications = []
        }

    }

    func addIgnoredApplication(_ application: IgnoredApplication) {
        guard !ignoredApplications.contains(
            where: { $0.bundleIdentifier == application.bundleIdentifier }
        ) else {
            return
        }

        ignoredApplications.append(application)
        ignoredApplications.sort {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func removeIgnoredApplication(_ application: IgnoredApplication) {
        ignoredApplications.removeAll { item in
            item.bundleIdentifier == application.bundleIdentifier
        }
    }

    func shouldIgnore(sourceBundleID: String) -> Bool {
        ignoredApplications.contains { application in
            application.bundleIdentifier == sourceBundleID
        }
    }

    private func saveIgnoredApplications() {
        guard let data = try? JSONEncoder().encode(ignoredApplications) else {
            return
        }

        defaults.set(data, forKey: Key.ignoredApplications)
    }
}
