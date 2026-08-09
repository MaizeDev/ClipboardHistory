//
//  HistoryPanelKeyboard.swift
//  ClipboardHistory
//

import AppKit

enum HistoryPanelCommand: Equatable {
    case moveSelection(Int)
    case chooseSelection
    case selectItem(at: Int)
    case deleteSelection
    case togglePin
    case dismiss

    var allowsKeyRepeat: Bool {
        if case .moveSelection = self {
            return true
        }

        return false
    }
}

enum HistoryPanelKeyboard {

    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126
    private static let returnKeyCodes: Set<UInt16> = [36, 76]
    private static let deleteKeyCodes: Set<UInt16> = [51, 117]
    private static let escapeKeyCode: UInt16 = 53

    static func command(
        keyCode: UInt16,
        charactersIgnoringModifiers: String?,
        modifierFlags: NSEvent.ModifierFlags
    ) -> HistoryPanelCommand? {
        let modifiers = normalizedModifiers(modifierFlags)

        if modifiers == [.command] {
            if deleteKeyCodes.contains(keyCode) {
                return .deleteSelection
            }

            if charactersIgnoringModifiers?.lowercased() == "p" {
                return .togglePin
            }

            if let character = charactersIgnoringModifiers,
               let number = Int(character),
               (1...9).contains(number) {
                return .selectItem(at: number - 1)
            }

            return nil
        }

        guard modifiers.isEmpty else {
            return nil
        }

        switch keyCode {
        case downArrowKeyCode:
            return .moveSelection(1)

        case upArrowKeyCode:
            return .moveSelection(-1)

        case _ where returnKeyCodes.contains(keyCode):
            return .chooseSelection

        case _ where deleteKeyCodes.contains(keyCode):
            return .deleteSelection

        case escapeKeyCode:
            return .dismiss

        default:
            return nil
        }
    }

    private static func normalizedModifiers(
        _ modifiers: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        modifiers
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
    }
}
