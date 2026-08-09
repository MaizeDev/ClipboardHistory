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
            shouldIgnoreCapture: { [weak self] sourceBundleID, contentType in
                self?.preferences.shouldIgnore(
                    sourceBundleID: sourceBundleID,
                    contentType: contentType
                ) ?? false
            }
        )
        let pasteService = PasteService()

        monitor.onCapture = { [weak manager] capture in
            guard let manager else {
                return
            }

            switch manager.add(capture: capture) {
            case .inserted:
                #if DEBUG
                print(
                    """
                    已新增剪贴板记录：
                    类型：\(capture.contentType.rawValue)
                    来源：\(capture.sourceAppName)
                    Hash：\(capture.contentHash)
                    """
                )
                #endif

            case .updatedExisting:
                #if DEBUG
                print(
                    """
                    已更新重复记录：
                    类型：\(capture.contentType.rawValue)
                    来源：\(capture.sourceAppName)
                    Hash：\(capture.contentHash)
                    """
                )
                #endif

            case .failed:
                print("剪贴板记录保存失败")
            }
        }

        historyManager = manager
        clipboardMonitor = monitor

        let panel = HistoryPanel(
            modelContainer: ClipboardHistoryApp.modelContainer,
            onDelete: { [weak manager] item in
                manager?.delete(item: item)
            },
            onTogglePin: { [weak manager] item in
                manager?.togglePinned(for: item)
            },
            onChoose: { [weak monitor] item in
                guard pasteService.copy(item: item) else {
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

        statusBarController = StatusBarController(
            onTogglePanel: { [weak panel] in
                panel?.toggle()
            },
            onPrintHistory: { [weak manager] in
                manager?.debugPrintAll()
            }
        )

        monitor.start()

        #if DEBUG
        print("ClipboardHistory 已启动")
        print("HistoryManager 已初始化")
        print("菜单栏状态项已创建")
        print("核心服务集成完成")
        #endif
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
        historyManager = nil
        statusBarController = nil

        #if DEBUG
        print("ClipboardHistory 即将退出")
        #endif
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
