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
    func copy(item: HistoryItem) -> Bool {
        switch item.type {
        case .text:
            guard let text = item.textContent else {
                return false
            }

            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)

        case .rtf:
            pasteboard.clearContents()

            let wroteRTF = pasteboard.setData(
                item.contentData,
                forType: .rtf
            )
            let wroteText = item.textContent.map { text in
                pasteboard.setString(text, forType: .string)
            } ?? false

            return wroteRTF || wroteText

        case .image:
            guard let image = item.imageContent else {
                return false
            }

            pasteboard.clearContents()
            return pasteboard.writeObjects([image])

        case .fileURL:
            guard let fileURL = item.fileURL else {
                return false
            }

            pasteboard.clearContents()
            return pasteboard.writeObjects([fileURL as NSURL])

        case .unknown:
            return false
        }
    }
}
