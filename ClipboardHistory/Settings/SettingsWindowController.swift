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
        onClearHistory: @escaping (_ includeBackups: Bool) -> Void,
        unprotectedItemCount: @escaping () -> Int,
        expiredItemCount: @escaping (Int) -> Int
    ) {
        let hostingController = NSHostingController(
            rootView: SettingsView(
                preferences: preferences,
                onClearHistory: onClearHistory,
                unprotectedItemCount: unprotectedItemCount,
                expiredItemCount: expiredItemCount
            )
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = "ClipboardHistory 偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 720, height: 600))
        window.center()
        window.setFrameAutosaveName("ClipboardHistorySettingsWindowV2")

        windowController = NSWindowController(window: window)
    }

    func show() {
        guard let window = windowController.window else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        // 自动保存的窗口位置可能来自已经拔掉的外接显示器，
        // 这时窗口存在但完全在屏幕外，看起来就像“打不开”。
        if !isOnVisibleScreen(window) {
            window.center()
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    private func isOnVisibleScreen(_ window: NSWindow) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(window.frame)
        }
    }

    func close() {
        windowController.close()
    }
}
