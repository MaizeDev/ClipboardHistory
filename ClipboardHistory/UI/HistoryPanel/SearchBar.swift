//
//  SearchBar.swift
//  ClipboardHistory
//

import SwiftUI

struct SearchBar: View {

    @Binding
    var text: String

    let focusRequest: Int

    @FocusState
    private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索文字、文件或来源应用", text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除搜索")
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .onAppear {
            isFocused = true
        }
        .onChange(of: focusRequest) {
            isFocused = true
        }
    }
}
