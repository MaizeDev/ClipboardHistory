//
//  HistoryItemCard.swift
//  ClipboardHistory
//

import AppKit
import SwiftUI

struct HistoryItemCard: View {

    let item: HistoryRow
    let isSelected: Bool

    /// 键盘焦点在列表上时，选中的卡片用强调色；
    /// 焦点在搜索框时，选中的卡片改用灰色，提示此时 Delete 不会删除记录。
    let isListFocused: Bool

    let referenceDate: Date
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onCopyOriginal: () -> Void
    let onCopyPlainText: () -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(HistoryStore.self)
    private var store

    @Environment(HistoryPanelViewState.self)
    private var panelState

    /// 检查文件是否还在的触发条件：文件列表变了，或者浮窗又被显示了一次。
    private struct FileExistenceCheck: Equatable {
        let fileURLs: [URL]
        let showCount: Int
    }

    /// 文件缩略图，按路径缓存。一个卡片里可能有多个文件。
    @State
    private var fileThumbnails: [String: NSImage] = [:]

    /// 这条记录里已经不存在（被删除或移动）的文件数量。
    @State
    private var missingFileCount = 0

    @State
    private var imageThumbnail: NSImage?

    @State
    private var imageLoadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            metadata
            contentPreview

            if supportsTextCopy {
                copyActions
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selectionFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectionStroke, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

    private var selectionFill: Color {
        guard isSelected else {
            return Color.primary.opacity(0.055)
        }

        return isListFocused
            ? Color.accentColor.opacity(0.18)
            : Color.primary.opacity(0.12)
    }

    private var selectionStroke: Color {
        guard isSelected else {
            return Color.primary.opacity(0.08)
        }

        return isListFocused
            ? Color.accentColor.opacity(0.55)
            : Color.primary.opacity(0.28)
    }

    private var copyActions: some View {
        HStack(spacing: 8) {
            Spacer()

            Button("保留格式", systemImage: "doc.on.clipboard") {
                onCopyOriginal()
            }
            .help("复制文字并保留原有格式")

            Button("纯文本", systemImage: "textformat") {
                onCopyPlainText()
            }
            .help("只复制文字，去掉字体、颜色和链接格式")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var metadata: some View {
        HStack(spacing: 8) {
            Image(nsImage: sourceApplicationIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            Text(sourceApplicationName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(
                HistoryRelativeTimeFormatter.string(
                    from: item.timestamp,
                    relativeTo: referenceDate
                )
            )
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button(
                item.isFavorite ? "取消收藏" : "收藏",
                systemImage: item.isFavorite ? "star.fill" : "star",
                action: toggleFavorite
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(
                item.isFavorite ? Color.yellow : Color.secondary
            )
            .help(item.isFavorite ? "取消收藏" : "长期收藏这条内容")

            Button(
                item.isPinned ? "取消固定" : "固定",
                systemImage: item.isPinned ? "pin.fill" : "pin",
                action: togglePin
            )
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(
                item.isPinned ? Color.accentColor : Color.secondary
            )
            .help(item.isPinned ? "取消固定" : "固定到历史顶部（最多 3 条）")
        }
    }

    private func togglePin() {
        guard !reduceMotion else {
            onTogglePin()
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            onTogglePin()
        }
    }

    private func toggleFavorite() {
        guard !reduceMotion else {
            onToggleFavorite()
            return
        }

        withAnimation(.bouncy(duration: 0.25, extraBounce: 0.12)) {
            onToggleFavorite()
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .text, .rtf:
            Text(store.previewText(for: item) ?? "无法读取文字内容")
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3, reservesSpace: true)

        case .image:
            imagePreview

        case .fileURL:
            let fileURLs = item.fileURLs

            if fileURLs.isEmpty {
                unavailablePreview("无法读取文件", systemImage: "doc")
            } else {
                filePreview(fileURLs)
            }

        case .unknown:
            unavailablePreview("暂不支持的剪贴板内容", systemImage: "questionmark.square")
        }
    }

    /// 图片预览：使用后台生成并缓存的缩略图，不在界面刷新时解码整张图片。
    @ViewBuilder
    private var imagePreview: some View {
        let thumbnail = store.cachedThumbnail(for: item) ?? imageThumbnail

        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipShape(.rect(cornerRadius: 10))
            } else if imageLoadFailed {
                unavailablePreview("无法读取图片", systemImage: "photo")
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
        }
        .task(id: item.contentHash) {
            imageLoadFailed = false

            guard store.cachedThumbnail(for: item) == nil else {
                return
            }

            imageThumbnail = nil

            let image = await store.thumbnail(for: item)

            imageThumbnail = image
            imageLoadFailed = (image == nil)
        }
    }

    private func filePreview(_ fileURLs: [URL]) -> some View {
        Group {
            if fileURLs.count == 1 {
                singleFilePreview(fileURLs[0])
            } else {
                multipleFilePreview(fileURLs)
            }
        }
        .task(id: fileURLs) {
            await loadFileThumbnails(for: fileURLs)
        }
        .task(
            id: FileExistenceCheck(
                fileURLs: fileURLs,
                showCount: panelState.showCount
            )
        ) {
            missingFileCount = fileURLs.filter { url in
                !FileManager.default.fileExists(atPath: url.path)
            }.count
        }
    }

    /// 单个文件保留原来的大预览。
    private func singleFilePreview(_ fileURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))

                if let thumbnail = fileThumbnails[fileURL.path] {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else {
                    Image(nsImage: fileIcon(for: fileURL))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 120)
            .clipShape(.rect(cornerRadius: 10))

            fileDescription([fileURL])
        }
    }

    /// 多个文件用一排缩略图展示；超过 5 个时，最后一块显示“+N 个文件”。
    private func multipleFilePreview(_ fileURLs: [URL]) -> some View {
        let maximumTileCount = 5
        let showsOverflow = fileURLs.count > maximumTileCount
        let visibleCount = showsOverflow ? maximumTileCount - 1 : fileURLs.count
        let visibleURLs = Array(fileURLs.prefix(visibleCount))
        let overflowCount = fileURLs.count - visibleCount

        let tileWidth: CGFloat = visibleCount <= 3 ? 110 : 72
        let tileHeight: CGFloat = visibleCount <= 3 ? 88 : 66
        let tileSize = CGSize(width: tileWidth, height: tileHeight)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(
                    Array(visibleURLs.enumerated()),
                    id: \.offset
                ) { _, fileURL in
                    fileTile(fileURL, size: tileSize)
                }

                if showsOverflow {
                    overflowTile(count: overflowCount, size: tileSize)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            fileDescription(fileURLs)
        }
    }

    private func fileTile(_ fileURL: URL, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))

            if let thumbnail = fileThumbnails[fileURL.path] {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(nsImage: fileIcon(for: fileURL))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func overflowTile(count: Int, size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.06))

            VStack(spacing: 1) {
                Text("+\(count)")
                    .font(.callout.weight(.semibold))
                Text("个文件")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    /// 文件名、缺失提示和所属文件夹。
    private func fileDescription(_ fileURLs: [URL]) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(fileTitle(for: fileURLs))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                if missingFileCount > 0 {
                    Text(missingFilesDescription(total: fileURLs.count))
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(fileSubtitle(for: fileURLs))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            Image(nsImage: fileIcon(for: fileURLs[0]))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
        }
    }

    /// 为当前卡片展示的文件加载缩略图；失败的会回退到文件图标。
    private func loadFileThumbnails(for fileURLs: [URL]) async {
        let maximumThumbnailCount = 5
        let targetURLs = Array(fileURLs.prefix(maximumThumbnailCount))
        let targetPaths = Set(targetURLs.map(\.path))

        fileThumbnails = fileThumbnails.filter {
            targetPaths.contains($0.key)
        }

        for fileURL in targetURLs where fileThumbnails[fileURL.path] == nil {
            if let thumbnail = await FileThumbnailService.shared.thumbnail(
                for: fileURL
            ) {
                fileThumbnails[fileURL.path] = thumbnail
            }
        }
    }

    /// 一个文件显示文件名；多个文件显示“第一个文件名 等 N 个文件”。
    private func fileTitle(for fileURLs: [URL]) -> String {
        guard fileURLs.count > 1 else {
            return fileURLs[0].lastPathComponent
        }

        return "\(fileURLs[0].lastPathComponent) 等 \(fileURLs.count) 个文件"
    }

    private func missingFilesDescription(total: Int) -> String {
        if total == 1 {
            return "文件已不存在"
        }

        if missingFileCount >= total {
            return "\(total) 个文件都已不存在"
        }

        return "其中 \(missingFileCount) 个文件已不存在"
    }

    /// 所有文件在同一个文件夹时显示该文件夹，否则显示“来自多个位置”。
    private func fileSubtitle(for fileURLs: [URL]) -> String {
        let folders = Set(
            fileURLs.map { $0.deletingLastPathComponent().path }
        )

        if folders.count == 1, let folder = folders.first {
            return folder
        }

        return "来自多个位置"
    }

    private var sourceApplicationName: String {
        item.sourceAppName.isEmpty ? "未知来源" : item.sourceAppName
    }

    private var supportsTextCopy: Bool {
        item.supportsPlainText
    }

    private func fileIcon(for fileURL: URL) -> NSImage {
        HistoryPreviewCache.shared.fileIcon(forPath: fileURL.path)
    }

    private var sourceApplicationIcon: NSImage {
        HistoryPreviewCache.shared.sourceIcon(
            bundleID: item.sourceBundleID,
            fallbackDescription: sourceApplicationName
        )
    }

    private func unavailablePreview(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.body)
            .foregroundStyle(.secondary)
    }
}
