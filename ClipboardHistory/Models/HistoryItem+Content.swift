//
//  HistoryItem+Content.swift
//  ClipboardHistory
//

extension HistoryItem {

    /// 只有文字和富文本才能“纯文本复制”。
    /// 图片和文件没有对应的纯文本形式。
    var supportsPlainText: Bool {
        type == .text || type == .rtf
    }
}
