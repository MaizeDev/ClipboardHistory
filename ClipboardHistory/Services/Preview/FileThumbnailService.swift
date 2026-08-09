//
//  FileThumbnailService.swift
//  ClipboardHistory
//

import AppKit
import QuickLookThumbnailing

@MainActor
final class FileThumbnailService {

    static let shared = FileThumbnailService()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 120
    }

    func thumbnail(for fileURL: URL) async -> NSImage? {
        let cacheKey = fileURL.path as NSString

        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: 320, height: 220),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        do {
            let representation = try await QLThumbnailGenerator.shared
                .generateBestRepresentation(for: request)

            guard !Task.isCancelled else {
                return nil
            }

            let image = representation.nsImage
            cache.setObject(image, forKey: cacheKey)
            return image
        } catch {
            return nil
        }
    }
}
