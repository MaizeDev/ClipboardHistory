//
//  ImageThumbnailService.swift
//  ClipboardHistory
//

import AppKit
import ImageIO

/// 在后台把图片缩小成缩略图，并按内容哈希缓存。
///
/// 原来卡片每次渲染都对整张图片做一次全尺寸解码（`NSImage(data:)`），
/// 截图这类大图会明显拖慢界面。现在只解码一次缩小后的版本，而且不在主线程做。
@MainActor
final class ImageThumbnailService {

    static let shared = ImageThumbnailService()

    /// 缩略图较长一边的最大像素数。
    /// 卡片里图片最高 120 点、最宽约 430 点，按 2 倍屏需要不到 900 像素。
    private static let maximumPixelSize = 900

    private let cache = NSCache<NSString, NSImage>()

    /// 同一张图同时被多张卡片请求时，共用同一个生成任务，避免重复解码。
    private var inFlightTasks: [String: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 120

        // 只按数量限制时，150 张 900px 的缩略图可能占用上百 MB。
        // 改为按像素字节数限制，内存压力大时 NSCache 也会自动回收。
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// 只查缓存，不生成。用于在 `body` 里同步取已经生成好的缩略图，避免闪烁。
    func cachedThumbnail(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func thumbnail(
        forKey key: String,
        data: Data
    ) async -> NSImage? {
        if let cached = cachedThumbnail(forKey: key) {
            return cached
        }

        if let inFlightTask = inFlightTasks[key] {
            return await inFlightTask.value
        }

        let maximumPixelSize = Self.maximumPixelSize

        let task = Task<NSImage?, Never> {
            let box = await Task.detached(priority: .userInitiated) {
                Self.makeThumbnail(
                    from: data,
                    maximumPixelSize: maximumPixelSize
                )
            }.value

            guard let cgImage = box?.value else {
                return nil
            }

            let image = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )

            cache.setObject(
                image,
                forKey: key as NSString,
                cost: cgImage.bytesPerRow * cgImage.height
            )

            return image
        }

        inFlightTasks[key] = task

        let image = await task.value
        inFlightTasks[key] = nil

        return image
    }

    private nonisolated static func makeThumbnail(
        from data: Data,
        maximumPixelSize: Int
    ) -> UncheckedSendableBox<CGImage>? {
        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            sourceOptions
        ) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions
        ) else {
            return nil
        }

        return UncheckedSendableBox(value: image)
    }
}

/// `CGImage` 是不可变的，可以安全地跨线程传递，
/// 但编译器不知道，所以用这个盒子告诉它。
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}
