//
//  ShortcutSettingsView.swift
//  ClipboardHistory
//

import SwiftUI

struct ShortcutSettingsView: View {

    /// 恢复默认后递增，强制重建录制控件以刷新显示。
    @State
    private var resetVersion = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionCard(title: "可以修改", icon: "command") {
                ForEach(EditableClipboardShortcut.allCases) { shortcut in
                    ShortcutRecorderRow(shortcut: shortcut)

                    if shortcut != EditableClipboardShortcut.allCases.last {
                        Divider()
                    }
                }
            }
            .id(resetVersion)

            SettingsSectionCard(title: "浮窗基本操作", icon: "rectangle.on.rectangle") {
                Grid(horizontalSpacing: 28, verticalSpacing: 10) {
                    GridRow {
                        ShortcutReferenceRow(title: "移动选择", keys: "↑ / ↓")
                        ShortcutReferenceRow(title: "复制并关闭", keys: "Enter")
                    }
                    GridRow {
                        ShortcutReferenceRow(title: "选择第 1–9 条", keys: "⌘1–9")
                        ShortcutReferenceRow(title: "删除选中记录", keys: "Delete")
                    }
                    GridRow {
                        ShortcutReferenceRow(title: "关闭浮窗", keys: "Esc")
                        ShortcutReferenceRow(title: "鼠标快速复制", keys: "双击")
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                Text("基本操作保持 Mac 通用习惯，避免与输入和系统命令冲突。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("恢复默认快捷键") {
                    EditableClipboardShortcut.resetAll()
                    resetVersion += 1
                }
            }

            Spacer(minLength: 0)
        }
    }
}
