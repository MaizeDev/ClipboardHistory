//
//  SettingsSectionCard.swift
//  ClipboardHistory
//

import SwiftUI

struct SettingsSectionCard<Content: View>: View {

    let title: String
    let icon: String?
    let content: Content

    init(
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.55),
                in: .rect(cornerRadius: 11)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
    }
}
