//
//  StatusBarController.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//

import AppKit

@MainActor
final class StatusBarController: NSObject {

    private let statusItem: NSStatusItem
    private let contextMenu = NSMenu()
    private let onTogglePanel: () -> Void
    private let onPrintHistory: () -> Void

    init(
        onTogglePanel: @escaping () -> Void,
        onPrintHistory: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        self.onTogglePanel = onTogglePanel
        self.onPrintHistory = onPrintHistory

        super.init()

        configureStatusItem()
        configureContextMenu()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            assertionFailure("无法创建菜单栏按钮")
            return
        }

        button.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "剪贴板历史"
        )

        button.image?.isTemplate = true
        button.toolTip = "剪贴板历史（⇧⌘C）"

        button.target = self
        button.action = #selector(handleStatusItemClick(_:))

        button.sendAction(
            on: [
                .leftMouseUp,
                .rightMouseUp
            ]
        )
    }

    private func configureContextMenu() {
        let settingsItem = NSMenuItem(
            title: "偏好设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )

        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self

        let quitItem = NSMenuItem(
            title: "退出 ClipboardHistory",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )

        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self

        contextMenu.addItem(settingsItem)

        #if DEBUG
        let printHistoryItem = NSMenuItem(
            title: "打印历史",
            action: #selector(printHistory),
            keyEquivalent: ""
        )
        printHistoryItem.target = self
        contextMenu.addItem(printHistoryItem)
        #endif

        contextMenu.addItem(.separator())
        contextMenu.addItem(quitItem)
    }

    @objc
    private func handleStatusItemClick(
        _ sender: NSStatusBarButton
    ) {
        guard let event = NSApp.currentEvent else {
            return
        }

        switch event.type {
        case .rightMouseUp:
            showContextMenu()

        case .leftMouseUp:
            handleLeftClick()

        default:
            break
        }
    }

    private func handleLeftClick() {
        onTogglePanel()
    }

    private func showContextMenu() {
        statusItem.menu = contextMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func printHistory() {
        onPrintHistory()
    }

    @objc
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        let didOpen = NSApp.sendAction(
            Selector(("showSettingsWindow:")),
            to: nil,
            from: nil
        )

        if !didOpen {
            NSApp.sendAction(
                Selector(("showPreferencesWindow:")),
                to: nil,
                from: nil
            )
        }
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }
}
