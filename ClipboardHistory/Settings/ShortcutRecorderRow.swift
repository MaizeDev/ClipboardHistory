//
//  ShortcutRecorderRow.swift
//  ClipboardHistory
//

import SwiftUI

struct ShortcutRecorderRow: View {

    let shortcut: EditableClipboardShortcut

    /// 校验失败时显示在说明文字位置，避免录制控件自身变高导致整页跳动。
    @State
    private var feedbackMessage: String?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title)

                Text(feedbackMessage ?? shortcut.detail)
                    .font(.caption)
                    .foregroundStyle(
                        feedbackMessage == nil ? Color.secondary : Color.red
                    )
                    .lineLimit(1)
                    .help(feedbackMessage ?? shortcut.detail)
            }

            Spacer(minLength: 12)

            ShortcutRecorderField(shortcut: shortcut) { message in
                feedbackMessage = message
            }
        }
        .frame(minHeight: 34)
    }
}
