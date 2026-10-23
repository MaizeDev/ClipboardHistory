//
//  ClipboardShortcut.swift
//  ClipboardHistory
//

import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleHistoryPanel = Self(
        "toggleHistoryPanel",
        initial: .init(.c, modifiers: [.command, .shift])
    )

    static let togglePinnedItem = Self(
        "togglePinnedItem",
        initial: .init(.p, modifiers: [.command])
    )

    static let toggleFavoriteItem = Self(
        "toggleFavoriteItem",
        initial: .init(.f, modifiers: [.command, .shift])
    )

    static let chooseAlternativeCopyMode = Self(
        "chooseAlternativeCopyMode",
        initial: .init(.return, modifiers: [.option])
    )
}

enum EditableClipboardShortcut: CaseIterable, Identifiable {
    case showHistory
    case togglePin
    case toggleFavorite
    case alternativeCopy

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .showHistory:
            "打开剪贴板历史"
        case .togglePin:
            "固定或取消固定"
        case .toggleFavorite:
            "收藏或取消收藏"
        case .alternativeCopy:
            "使用另一种文字复制方式"
        }
    }

    var detail: String {
        switch self {
        case .showHistory:
            "在其他应用中也可以呼出或关闭浮窗"
        case .togglePin:
            "对浮窗中当前选中的卡片操作"
        case .toggleFavorite:
            "把当前卡片加入收藏或移出收藏"
        case .alternativeCopy:
            "临时切换保留格式或纯文本"
        }
    }

    var name: KeyboardShortcuts.Name {
        switch self {
        case .showHistory:
            .toggleHistoryPanel
        case .togglePin:
            .togglePinnedItem
        case .toggleFavorite:
            .toggleFavoriteItem
        case .alternativeCopy:
            .chooseAlternativeCopyMode
        }
    }

    @MainActor
    func validate(
        _ shortcut: KeyboardShortcuts.Shortcut
    ) -> KeyboardShortcuts.ValidationResult {
        if shortcut.isTakenBySystem {
            return .disallow(
                reason: "这个快捷键已被 macOS 使用，请换一个组合，或先到“系统设置 › 键盘 › 键盘快捷键”中修改。"
            )
        }

        if Self.isReservedTextEditingShortcut(shortcut) {
            return .disallow(
                reason: "这是文字输入和编辑的常用快捷键（复制、粘贴、撤销等），会干扰搜索框输入。"
            )
        }

        if let conflict = Self.allCases.first(where: {
            $0 != self && $0.name.shortcut == shortcut
        }) {
            return .disallow(
                reason: "这个快捷键已经用于“\(conflict.title)”。"
            )
        }

        if Self.isReservedPanelShortcut(shortcut) {
            return .disallow(
                reason: "这个快捷键已经用于浮窗的基本操作。"
            )
        }

        return .allow
    }

    @MainActor
    static func resetAll() {
        KeyboardShortcuts.reset(allCases.map(\.name))
    }

    /// 搜索框和系统文字编辑里约定俗成的快捷键。
    /// 如果把它们分配给应用内动作，用户在搜索框里按 ⌘C/⌘V/⌘Z 时会得到意外行为。
    private static func isReservedTextEditingShortcut(
        _ shortcut: KeyboardShortcuts.Shortcut
    ) -> Bool {
        guard let key = shortcut.key else {
            return false
        }

        let modifiers = shortcut.modifiers.intersection(
            .deviceIndependentFlagsMask
        )
        let normalized = KeyboardShortcuts.Shortcut(
            key,
            modifiers: modifiers
        )

        return reservedEditingShortcuts.contains(normalized)
    }

    private static let reservedEditingShortcuts: Set<
        KeyboardShortcuts.Shortcut
    > = [
        .init(.c, modifiers: [.command]),
        .init(.v, modifiers: [.command]),
        .init(.x, modifiers: [.command]),
        .init(.a, modifiers: [.command]),
        .init(.z, modifiers: [.command]),
        .init(.z, modifiers: [.command, .shift]),
        .init(.f, modifiers: [.command])
    ]

    private static func isReservedPanelShortcut(
        _ shortcut: KeyboardShortcuts.Shortcut
    ) -> Bool {
        let modifiers = shortcut.modifiers.intersection(
            .deviceIndependentFlagsMask
        )
        guard let key = shortcut.key else {
            return false
        }

        if modifiers.isEmpty {
            return [
                KeyboardShortcuts.Key.upArrow,
                .downArrow,
                .leftArrow,
                .rightArrow,
                .home,
                .end,
                .pageUp,
                .pageDown,
                .tab,
                .return,
                .escape,
                .delete,
                .deleteForward
            ]
            .contains(key)
        }

        if modifiers == [.command] {
            return [
                KeyboardShortcuts.Key.one,
                .two,
                .three,
                .four,
                .five,
                .six,
                .seven,
                .eight,
                .nine,
                .delete,
                .deleteForward
            ]
            .contains(key)
        }

        return false
    }
}
