//
//  HistoryPreviewCache.swift
//  ClipboardHistory
//

import AppKit

/// 卡片和搜索用到的“算一次就够”的数据缓存。
///
/// 这些内容原来都写在卡片的 `body` 或搜索过滤里，每次界面刷新都要重新计算，
/// 尤其是解析 RTF 和查询来源应用图标。现在按内容哈希缓存，同样的内容只算一次。
@MainActor
final class HistoryPreviewCache {

    static let shared = HistoryPreviewCache()

    /// 卡片预览最多显示的字符数。卡片只显示 3 行，没必要把超长文字全部交给界面。
    static let maximumPreviewCharacters = 600

    private let previewCache = NSCache<NSString, NSString>()
    private let fullTextCache = NSCache<NSString, NSString>()
    private let iconCache = NSCache<NSString, NSImage>()

    private init() {
        previewCache.countLimit = 500

        // 全文按字符数计成本，总量限制在约 32 MB，避免搜索时把大量长文本一直留在内存里。
        fullTextCache.totalCostLimit = 32 * 1024 * 1024

        iconCache.countLimit = 100
    }

    // MARK: - Text

    /// 卡片上显示的预览文字（最多 `maximumPreviewCharacters` 个字符）。
    /// 命中缓存时直接返回；没有缓存时调用 `compute` 取完整文字，截断后缓存。
    func previewText(
        forKey key: String,
        compute: () -> String?
    ) -> String? {
        let cacheKey = key as NSString

        if let cached = previewCache.object(forKey: cacheKey) {
            return cached as String
        }

        guard let text = compute() else {
            return nil
        }

        let preview = String(text.prefix(Self.maximumPreviewCharacters))
        previewCache.setObject(preview as NSString, forKey: cacheKey)

        return preview
    }

    /// 搜索用的完整文字。只有在真正搜索时才会读取。
    func fullText(
        forKey key: String,
        compute: () -> String?
    ) -> String? {
        let cacheKey = key as NSString

        if let cached = fullTextCache.object(forKey: cacheKey) {
            return cached as String
        }

        guard let text = compute() else {
            return nil
        }

        fullTextCache.setObject(
            text as NSString,
            forKey: cacheKey,
            cost: text.utf16.count * 2
        )

        return text
    }

    // MARK: - File icon

    /// 文件图标。文件卡片每次刷新都会绘制图标，
    /// 直接同步调用 `NSWorkspace.icon(forFile:)` 会在滚动时反复查磁盘和 LaunchServices。
    func fileIcon(forPath path: String) -> NSImage {
        let key = "file:\(path)" as NSString

        if let cached = iconCache.object(forKey: key) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(icon, forKey: key)

        return icon
    }

    // MARK: - Source application icon

    func sourceIcon(
        bundleID: String,
        fallbackDescription: String
    ) -> NSImage {
        let key = bundleID as NSString

        if let cached = iconCache.object(forKey: key) {
            return cached
        }

        let icon: NSImage

        if !bundleID.isEmpty,
           let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
           ) {
            icon = NSWorkspace.shared.icon(forFile: applicationURL.path)
        } else {
            icon = NSImage(
                systemSymbolName: "app",
                accessibilityDescription: fallbackDescription
            ) ?? NSImage()
        }

        iconCache.setObject(icon, forKey: key)

        return icon
    }
}
