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

    /// 同一个文件同时被多张卡片请求时，共用同一个 Quick Look 请求。
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 32 * 1024 * 1024
    }

    func thumbnail(for fileURL: URL) async -> NSImage? {
        let cacheKey = fileURL.path as NSString

        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        let path = fileURL.path

        if let inFlightTask = inFlightTasks[path] {
            return await inFlightTask.value
        }

        let task = Task<NSImage?, Never> {
            guard FileManager.default.fileExists(atPath: path) else {
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

                let pixelWidth = Int(image.size.width * 2)
                let pixelHeight = Int(image.size.height * 2)

                cache.setObject(
                    image,
                    forKey: cacheKey,
                    cost: max(pixelWidth * pixelHeight * 4, 1)
                )

                return image
            } catch {
                return nil
            }
        }

        inFlightTasks[path] = task

        let image = await task.value
        inFlightTasks[path] = nil

        return image
    }
}
