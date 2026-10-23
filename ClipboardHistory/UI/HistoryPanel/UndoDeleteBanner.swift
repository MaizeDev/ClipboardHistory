//
//  UndoDeleteBanner.swift
//  ClipboardHistory
//

import SwiftUI

/// 删除记录后出现在面板底部的提示条，几秒后自动消失。
struct UndoDeleteBanner: View {

    let count: Int
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(count > 1 ? "已删除 \(count) 条记录" : "已删除 1 条记录")
                .font(.callout)

            Button("撤销", action: onUndo)
                .buttonStyle(.borderless)
                .fontWeight(.semibold)
                .help("撤销删除（⌘Z）")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.thickMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .accessibilityElement(children: .contain)
    }
}
