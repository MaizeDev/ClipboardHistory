//
//  HistoryItem.swift
//  ClipboardHistory
//
//  Created by wheat on 8/6/26.
//

import AppKit
import CryptoKit
import Foundation
import SwiftData

enum ClipboardContentType: String, Codable, CaseIterable {
    case text
    case rtf
    case image
    case fileURL
    case unknown
}

@Model
final class HistoryItem {

    // MARK: - Stored properties

    @Attribute(.unique)
    var id: UUID

    @Attribute(.externalStorage)
    var contentData: Data

    var contentType: String
    var timestamp: Date

    var sourceAppName: String
    var sourceBundleID: String

    var isPinned: Bool
    var pinnedAt: Date?
    var isFavorite: Bool = false
    var favoritedAt: Date?
    var contentHash: String

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        contentData: Data,
        contentType: ClipboardContentType,
        timestamp: Date = .now,
        sourceAppName: String = "",
        sourceBundleID: String = "",
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        isFavorite: Bool = false,
        favoritedAt: Date? = nil,
        contentHash: String? = nil
    ) {
        self.id = id
        self.contentData = contentData
        self.contentType = contentType.rawValue
        self.timestamp = timestamp
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
        self.pinnedAt = pinnedAt
        self.isFavorite = isFavorite
        self.favoritedAt = favoritedAt
        self.contentHash = contentHash
            ?? Self.generateContentHash(
                data: contentData,
                type: contentType
            )
    }

    // MARK: - Content type

    var type: ClipboardContentType {
        get {
            ClipboardContentType(rawValue: contentType) ?? .unknown
        }
        set {
            contentType = newValue.rawValue
        }
    }

    // MARK: - Content conversion

    var textContent: String? {
        switch type {
        case .text:
            return String(data: contentData, encoding: .utf8)

        case .rtf:
            return NSAttributedString(
                rtf: contentData,
                documentAttributes: nil
            )?.string

        case .fileURL:
            return fileURL?.path

        case .image, .unknown:
            return nil
        }
    }

    var attributedContent: NSAttributedString? {
        guard type == .rtf else {
            return nil
        }

        return NSAttributedString(
            rtf: contentData,
            documentAttributes: nil
        )
    }

    var imageContent: NSImage? {
        guard type == .image else {
            return nil
        }

        return NSImage(data: contentData)
    }

    var fileURL: URL? {
        guard type == .fileURL,
              let path = String(data: contentData, encoding: .utf8),
              !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path)
    }

    // MARK: - Hash

    static func generateContentHash(
        data: Data,
        type: ClipboardContentType
    ) -> String {
        var hashInput = Data(type.rawValue.utf8)
        hashInput.append(data)

        let digest = SHA256.hash(data: hashInput)

        return digest.map {
            String(format: "%02x", $0)
        }
        .joined()
    }
}
