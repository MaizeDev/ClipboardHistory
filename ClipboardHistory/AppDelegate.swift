//
//  AppDelegate.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//


import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let preferences = AppPreferences()

    private var statusBarController: StatusBarController?
    private var historyManager: HistoryManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var historyPanel: HistoryPanel?
    private var hotKeyManager: HotKeyManager?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let manager = HistoryManager(
            modelContainer: ClipboardHistoryApp.modelContainer,
            maximumUnpinnedItemCount: { [weak preferences] in
                preferences?.maximumHistoryCount ?? 1_000
            }
        )

        preferences.onMaximumHistoryCountChange = { [weak manager] in
            manager?.cleanupIfNeeded()
        }

        let monitor = ClipboardMonitor(
            shouldIgnoreSourceApplication: { [weak self] sourceBundleID in
                self?.preferences.shouldIgnore(sourceBundleID: sourceBundleID)
                    ?? false
            }
        )
        let pasteService = PasteService()

        monitor.onCapture = { [weak manager] capture in
            manager?.add(capture: capture)
        }

        historyManager = manager
        clipboardMonitor = monitor

        let panel = HistoryPanel(
            modelContainer: ClipboardHistoryApp.modelContainer,
            preferences: preferences,
            onDelete: { [weak manager] item in
                manager?.delete(item: item)
            },
            onTogglePin: { [weak manager] item in
                manager?.togglePinned(for: item)
            },
            onToggleFavorite: { [weak manager] item in
                manager?.toggleFavorite(for: item)
            },
            onChoose: { [weak monitor] item, mode in
                guard pasteService.copy(item: item, mode: mode) else {
                    return false
                }

                monitor?.markCurrentChangeAsSelfWrite()
                return true
            }
        )
        historyPanel = panel
        hotKeyManager = HotKeyManager(
            onTogglePanel: { [weak panel] in
                panel?.toggle()
            }
        )

        let settingsController = SettingsWindowController(
            preferences: preferences,
            onClearHistory: { [weak manager] in
                manager?.deleteAll()
            }
        )
        settingsWindowController = settingsController

        statusBarController = StatusBarController(
            onTogglePanel: { [weak panel] in
                panel?.toggle()
            },
            onOpenSettings: { [weak settingsController] in
                settingsController?.show()
            }
        )

        monitor.start()
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        clipboardMonitor?.stop()
        clipboardMonitor = nil

        historyPanel?.hide()
        historyPanel = nil
        hotKeyManager?.stop()
        hotKeyManager = nil
        settingsWindowController?.close()
        settingsWindowController = nil
        historyManager = nil
        statusBarController = nil

    }

    func clearHistory() {
        historyManager?.deleteAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }
}
