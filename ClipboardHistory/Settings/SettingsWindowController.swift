//
//  SettingsWindowController.swift
//  ClipboardHistory
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {

    private let windowController: NSWindowController

    init(
        preferences: AppPreferences,
        onClearHistory: @escaping () -> Void
    ) {
        let hostingController = NSHostingController(
            rootView: SettingsView(
                preferences: preferences,
                onClearHistory: onClearHistory
            )
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ClipboardHistory 偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center()
        window.setFrameAutosaveName("ClipboardHistorySettingsWindow")

        windowController = NSWindowController(window: window)
    }

    func show() {
        guard let window = windowController.window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        windowController.close()
    }
}
