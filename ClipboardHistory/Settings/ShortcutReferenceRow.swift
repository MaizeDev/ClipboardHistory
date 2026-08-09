//
//  ShortcutReferenceRow.swift
//  ClipboardHistory
//

import SwiftUI

struct ShortcutReferenceRow: View {

    let title: String
    let keys: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(keys)
                .font(.body.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity)
    }
}
