//
//  HotKeyManager.swift
//  ClipboardHistory
//

import AppKit
import KeyboardShortcuts
import OSLog

private let hotKeyLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "ClipboardHistory",
    category: "HotKey"
)

@MainActor
final class HotKeyManager {

    private let onTogglePanel: () -> Void
    private var listenerTask: Task<Void, Never>?

    init(onTogglePanel: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
        start()
    }

    var isRegistered: Bool {
        KeyboardShortcuts.isEnabled(for: .toggleHistoryPanel)
    }

    func start() {
        guard listenerTask == nil else {
            return
        }

        listenerTask = Task { [weak self] in
            let events = KeyboardShortcuts.events(
                for: .toggleHistoryPanel
            )

            if !KeyboardShortcuts.isEnabled(for: .toggleHistoryPanel) {
                hotKeyLogger.warning(
                    "全局快捷键未启用，可能与其他 App 的快捷键冲突"
                )
            }

            for await event in events where event == .keyUp {
                guard !Task.isCancelled else {
                    return
                }

                self?.onTogglePanel()
            }
        }
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
    }
}
