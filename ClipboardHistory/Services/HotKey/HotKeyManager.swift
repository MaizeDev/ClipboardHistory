//
//  HotKeyManager.swift
//  ClipboardHistory
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {

    static let toggleHistoryPanel = Self(
        "toggleHistoryPanel",
        initial: .init(.c, modifiers: [.command, .shift])
    )
}

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
                print(
                    "全局快捷键 ⇧⌘C 注册失败，可能已被其他 App 占用"
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
