//
//  PasteService.swift
//  ClipboardHistory
//

import AppKit

@MainActor
final class PasteService {

    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    func copy(item: HistoryItem, mode: ClipboardCopyMode) -> Bool {
        // 图片和文件没有“纯文本”形式。
        // 默认模式是纯文本时，遇到它们要回退成原样复制，否则按 Enter 会没有任何反应。
        let effectiveMode: ClipboardCopyMode =
            (mode == .plainText && !item.supportsPlainText) ? .original : mode

        if effectiveMode == .plainText {
            return copyAsPlainText(item)
        }

        switch item.type {
        case .text:
            guard let text = item.textContent else {
                return false
            }

            pasteboard.clearContents()

            let wroteText = pasteboard.setString(text, forType: .string)
            let wroteExtras = writeAdditionalFormats(
                of: item,
                alreadyWritten: [.string]
            )

            return wroteText || wroteExtras

        case .rtf:
            pasteboard.clearContents()

            let wroteRTF = pasteboard.setData(
                item.contentData,
                forType: .rtf
            )
            let wroteText = item.textContent.map { text in
                pasteboard.setString(text, forType: .string)
            } ?? false
            let wroteExtras = writeAdditionalFormats(
                of: item,
                alreadyWritten: [.rtf, .string]
            )

            return wroteRTF || wroteText || wroteExtras

        case .image:
            guard let image = item.imageContent else {
                return false
            }

            pasteboard.clearContents()
            return pasteboard.writeObjects([image])

        case .fileURL:
            // 已经被删除或移动的文件无法粘贴，写回时跳过它们。
            // 全部都不存在时返回 false，面板保持打开（卡片上会提示文件已不存在）。
            let existingURLs = item.fileURLs.filter { url in
                FileManager.default.fileExists(atPath: url.path)
            }

            guard !existingURLs.isEmpty else {
                return false
            }

            pasteboard.clearContents()
            return pasteboard.writeObjects(existingURLs.map { $0 as NSURL })

        case .unknown:
            return false
        }
    }

    /// 把记录里附加保存的其他格式（HTML、图片等）也写回剪贴板，
    /// 这样粘贴到不同应用里的效果，和直接复制时一致。
    /// `alreadyWritten` 是已经写过的类型，不再重复写。
    private func writeAdditionalFormats(
        of item: HistoryItem,
        alreadyWritten: Set<NSPasteboard.PasteboardType>
    ) -> Bool {
        var wroteAny = false

        for format in item.formats {
            let type = NSPasteboard.PasteboardType(format.type)

            guard !alreadyWritten.contains(type) else {
                continue
            }

            if pasteboard.setData(format.data, forType: type) {
                wroteAny = true
            }
        }

        return wroteAny
    }

    private func copyAsPlainText(_ item: HistoryItem) -> Bool {
        guard item.supportsPlainText,
              let text = item.textContent else {
            return false
        }

        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }
}
