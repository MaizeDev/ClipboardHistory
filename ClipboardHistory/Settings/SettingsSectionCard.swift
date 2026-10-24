//
//  SettingsSectionCard.swift
//  ClipboardHistory
//

import SwiftUI

struct SettingsSectionCard<Content: View>: View {

    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.quaternary.opacity(0.65))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
}
