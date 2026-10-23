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
    private let pauseMenuItem = NSMenuItem()
    private let isRecordingPaused: () -> Bool
    private let onToggleRecordingPaused: () -> Void
    private let onTogglePanel: () -> Void
    private let onOpenSettings: () -> Void

    init(
        isRecordingPaused: @escaping () -> Bool,
        onToggleRecordingPaused: @escaping () -> Void,
        onTogglePanel: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        self.isRecordingPaused = isRecordingPaused
        self.onToggleRecordingPaused = onToggleRecordingPaused
        self.onTogglePanel = onTogglePanel
        self.onOpenSettings = onOpenSettings

        super.init()

        configureStatusItem()
        configureContextMenu()
        refreshAppearance()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            assertionFailure("无法创建菜单栏按钮")
            return
        }

        button.imageScaling = .scaleProportionallyDown

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
        pauseMenuItem.action = #selector(toggleRecordingPaused)
        pauseMenuItem.target = self

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

        contextMenu.addItem(pauseMenuItem)
        contextMenu.addItem(.separator())
        contextMenu.addItem(settingsItem)
        contextMenu.addItem(.separator())
        contextMenu.addItem(quitItem)
    }

    /// 根据是否暂停记录，更新菜单栏图标和菜单项标题。
    private func refreshAppearance() {
        let isPaused = isRecordingPaused()

        pauseMenuItem.title = isPaused ? "恢复记录" : "暂停记录"

        guard let button = statusItem.button else {
            return
        }

        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 15,
            weight: .regular
        )

        let description = isPaused ? "剪贴板历史（已暂停记录）" : "剪贴板历史"

        button.image = NSImage(
            systemSymbolName: isPaused ? "pause.circle" : "doc.on.clipboard",
            accessibilityDescription: description
        )?.withSymbolConfiguration(symbolConfiguration)
        button.image?.isTemplate = true

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
        refreshAppearance()

        guard let button = statusItem.button else {
            return
        }

        // 让 AppKit 以“菜单栏图标菜单”的原生方式展示菜单。
        // 用 popUp(in:) 手工弹出时，macOS 27 会给菜单加一个多余的
        // 折叠/滚动箭头，看起来像多了一个折叠面板。
        statusItem.menu = contextMenu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc
    private func toggleRecordingPaused() {
        onToggleRecordingPaused()
        refreshAppearance()
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
