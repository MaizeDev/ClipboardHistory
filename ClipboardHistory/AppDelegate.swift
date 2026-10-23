//
//  AppDelegate.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//


import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let preferences = AppPreferences()

    private var statusBarController: StatusBarController?
    private var historyManager: HistoryManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var historyPanel: HistoryPanel?
    private var hotKeyManager: HotKeyManager?
    private var settingsWindowController: SettingsWindowController?
    private var retentionTimer: Timer?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let manager = HistoryManager(
            modelContainer: ClipboardHistoryApp.modelContainer,
            maximumUnpinnedItemCount: { [weak preferences] in
                preferences?.maximumHistoryCount ?? 1_000
            },
            retentionDays: { [weak preferences] in
                preferences?.historyRetentionDays ?? 0
            }
        )

        preferences.onMaximumHistoryCountChange = { [weak manager] in
            manager?.cleanupIfNeeded()
        }

        preferences.onHistoryRetentionDaysChange = { [weak manager] in
            manager?.cleanupIfNeeded()
        }

        let monitor = ClipboardMonitor(
            shouldIgnoreSourceApplication: { [weak self] sourceBundleID in
                self?.preferences.shouldIgnore(sourceBundleID: sourceBundleID)
                    ?? false
            },
            isRecordingPaused: { [weak self] in
                self?.preferences.isRecordingPaused ?? false
            }
        )
        let pasteService = PasteService()

        monitor.onCapture = { [weak manager] capture in
            manager?.add(capture: capture)
        }

        historyManager = manager
        clipboardMonitor = monitor

        let panel = HistoryPanel(
            store: manager.store,
            preferences: preferences,
            onDelete: { [weak manager] row in
                manager?.delete(id: row.id)
            },
            onRestore: { [weak manager] snapshot in
                manager?.restore(snapshot: snapshot) ?? false
            },
            onTogglePin: { [weak manager] row in
                manager?.togglePinned(id: row.id)
            },
            onToggleFavorite: { [weak manager] row in
                manager?.toggleFavorite(id: row.id)
            },
            onChoose: { [weak manager, weak monitor] row, mode in
                guard let item = manager?.store.item(id: row.id),
                      pasteService.copy(item: item, mode: mode) else {
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
            onClearHistory: { [weak self] includeBackups in
                self?.clearHistory(includingBackups: includeBackups)
            },
            unprotectedItemCount: { [weak self] in
                self?.unprotectedItemCount() ?? 0
            },
            expiredItemCount: { [weak self] days in
                self?.expiredItemCount(olderThanDays: days) ?? 0
            }
        )
        settingsWindowController = settingsController

        statusBarController = StatusBarController(
            isRecordingPaused: { [weak self] in
                self?.preferences.isRecordingPaused ?? false
            },
            onToggleRecordingPaused: { [weak self] in
                self?.preferences.isRecordingPaused.toggle()
            },
            onTogglePanel: { [weak panel] in
                panel?.toggle()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )

        monitor.start()

        // 启动时清理一次过期和超限的记录，之后每小时检查一次。
        manager.cleanupIfNeeded()

        retentionTimer = Timer.scheduledTimer(
            withTimeInterval: 60 * 60,
            repeats: true
        ) { [weak manager] _ in
            MainActor.assumeIsolated {
                manager?.cleanupIfNeeded()
            }
        }

        // 数据库出过问题（打不开、被迫新建）时，启动完成后告诉用户。
        if let issue = ModelContainerFactory.outcome.issue {
            presentPersistenceIssue(issue)
        }
    }

    private func presentPersistenceIssue(_ issue: PersistenceIssue) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = issue.title
        alert.informativeText = issue.message
        alert.addButton(withTitle: "好")

        if issue.revealURL != nil {
            alert.addButton(withTitle: "在 Finder 中显示")
        }

        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()

        if response == .alertSecondButtonReturn,
           let url = issue.revealURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// 打开偏好设置。
    ///
    /// 这里只使用菜单栏进程里手工创建的 `SettingsWindowController`。
    /// 之前尝试过 `showSettingsWindow:`，但菜单栏应用（LSUIElement）不是
    /// 常规前台应用，selector 可能返回 true 却不出现任何窗口；
    /// 同时保留手工窗口也能避免和 SwiftUI `Settings` 场景出现两个设置窗口。
    private func openSettings() {
        guard let settingsWindowController else {
            Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
                category: "AppDelegate"
            )
            .error("偏好设置窗口尚未创建")
            return
        }

        settingsWindowController.show()
    }

    func applicationWillTerminate(
        _ notification: Notification
    ) {
        retentionTimer?.invalidate()
        retentionTimer = nil

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

    /// 清空全部历史。`includingBackups` 为 true 时一并删除数据库备份。
    func clearHistory(includingBackups: Bool) {
        historyPanel?.clearUndoHistory()
        historyManager?.deleteAll()

        guard includingBackups else {
            return
        }

        do {
            try StoreBackup.deleteAllBackups()
        } catch {
            Logger(
                subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
                category: "AppDelegate"
            )
            .error(
                "删除数据库备份失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// 既没固定也没收藏、并且早于“保留 N 天”分界时间的记录数量。
    /// 设置页在选择自动删除天数之前，用它告诉用户会有多少条被删除。
    func expiredItemCount(olderThanDays days: Int) -> Int {
        guard days > 0,
              let rows = historyManager?.store.rows else {
            return 0
        }

        let cutoff = HistoryManager.retentionCutoff(days: days)

        return rows.filter { row in
            !row.isPinned && !row.isFavorite && row.timestamp < cutoff
        }.count
    }

    /// 既没固定也没收藏的记录数量。
    /// 设置页在调低“最多保留条数”之前，用它告诉用户会有多少条被删除。
    func unprotectedItemCount() -> Int {
        guard let rows = historyManager?.store.rows else {
            return 0
        }

        return rows.filter { !$0.isPinned && !$0.isFavorite }.count
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }
}
