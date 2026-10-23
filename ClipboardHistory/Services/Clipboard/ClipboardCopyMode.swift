//
//  ClipboardCopyMode.swift
//  ClipboardHistory
//

enum ClipboardCopyMode: String, CaseIterable, Identifiable {
    case original
    case plainText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            "保留格式"
        case .plainText:
            "纯文本"
        }
    }

    var alternative: ClipboardCopyMode {
        self == .original ? .plainText : .original
    }
}
