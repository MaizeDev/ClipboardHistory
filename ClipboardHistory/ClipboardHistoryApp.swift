//
//  ClipboardHistoryApp.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//

import SwiftData
import SwiftUI

@main
struct ClipboardHistoryApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    static let modelContainer: ModelContainer = {
        let schema = Schema([
            HistoryItem.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("无法创建 SwiftData ModelContainer：\(error)")
        }
    }()

    var body: some Scene {
        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                onClearHistory: appDelegate.clearHistory
            )
        }
        .modelContainer(Self.modelContainer)
    }
}
