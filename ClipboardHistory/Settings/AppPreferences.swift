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

    static let historyCountOptions = [100, 250, 500, 1_000, 2_000, 5_000]

    private enum Key {
        static let maximumHistoryCount = "maximumHistoryCount"
        static let ignoredApplications = "ignoredApplications"
        static let ignoredContentTypes = "ignoredContentTypes"
    }

    private static let defaultHistoryCount = 1_000

    var maximumHistoryCount: Int {
        didSet {
            guard oldValue != maximumHistoryCount else {
                return
            }

            defaults.set(maximumHistoryCount, forKey: Key.maximumHistoryCount)
            onMaximumHistoryCountChange?()
        }
    }

    private(set) var ignoredApplications: [IgnoredApplication] {
        didSet {
            saveIgnoredApplications()
        }
    }

    private(set) var ignoredContentTypes: Set<ClipboardContentType> {
        didSet {
            defaults.set(
                ignoredContentTypes.map(\.rawValue).sorted(),
                forKey: Key.ignoredContentTypes
            )
        }
    }

    @ObservationIgnored
    var onMaximumHistoryCountChange: (() -> Void)?

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedHistoryCount = defaults.integer(
            forKey: Key.maximumHistoryCount
        )
        maximumHistoryCount = Self.historyCountOptions.contains(
            storedHistoryCount
        ) ? storedHistoryCount : Self.defaultHistoryCount

        if let data = defaults.data(forKey: Key.ignoredApplications),
           let applications = try? JSONDecoder().decode(
               [IgnoredApplication].self,
               from: data
           ) {
            ignoredApplications = applications
        } else {
            ignoredApplications = []
        }

        let storedTypes = defaults.stringArray(
            forKey: Key.ignoredContentTypes
        ) ?? []
        ignoredContentTypes = Set(
            storedTypes.compactMap(ClipboardContentType.init(rawValue:))
        )
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

    func isIgnoring(_ type: ClipboardContentType) -> Bool {
        ignoredContentTypes.contains(type)
    }

    func setIgnoring(
        _ shouldIgnore: Bool,
        type: ClipboardContentType
    ) {
        if shouldIgnore {
            ignoredContentTypes.insert(type)
        } else {
            ignoredContentTypes.remove(type)
        }
    }

    func shouldIgnore(
        sourceBundleID: String,
        contentType: ClipboardContentType
    ) -> Bool {
        ignoredContentTypes.contains(contentType)
            || ignoredApplications.contains { application in
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
