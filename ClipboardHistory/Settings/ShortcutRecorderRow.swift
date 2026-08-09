//
//  ShortcutRecorderRow.swift
//  ClipboardHistory
//

import KeyboardShortcuts
import SwiftUI

struct ShortcutRecorderRow: View {

    let shortcut: EditableClipboardShortcut

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title)
                Text(shortcut.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            KeyboardShortcuts.Recorder(for: shortcut.name)
                .shortcutValidation(shortcut.validate)
        }
    }
}
