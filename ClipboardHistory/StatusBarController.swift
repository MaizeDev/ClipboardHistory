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
    private let onOpenSettings: () -> Void

    init(
        onTogglePanel: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        self.onTogglePanel = onTogglePanel
        self.onOpenSettings = onOpenSettings

        super.init()

        configureStatusItem()
        configureContextMenu()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            assertionFailure("无法创建菜单栏按钮")
            return
        }

        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 15,
            weight: .regular
        )
        button.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "剪贴板历史"
        )?.withSymbolConfiguration(symbolConfiguration)
        button.image?.isTemplate = true

        button.imageScaling = .scaleProportionallyDown
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
    private func openSettings() {
        onOpenSettings()
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }
}
