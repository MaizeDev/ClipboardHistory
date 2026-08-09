//
//  HistoryItemCard.swift
//  ClipboardHistory
//

import AppKit
import SwiftUI

struct HistoryItemCard: View {

    let item: HistoryItem
    let isSelected: Bool
    let referenceDate: Date
    let showsCopyActions: Bool
    let onCopyOriginal: () -> Void
    let onCopyPlainText: () -> Void

    @State
    private var fileThumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            metadata
            contentPreview

            if showsCopyActions {
                copyActions
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected
                        ? Color.accentColor.opacity(0.18)
                        : Color.primary.opacity(0.055)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected
                        ? Color.accentColor.opacity(0.55)
                        : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
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

            Text(sourceApplicationName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("已固定")
            }

            Text(
                HistoryRelativeTimeFormatter.string(
                    from: item.timestamp,
                    relativeTo: referenceDate
                )
            )
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.type {
        case .text, .rtf:
            Text(item.textContent ?? "无法读取文字内容")
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)

        case .image:
            if let image = item.imageContent {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                unavailablePreview("无法读取图片", systemImage: "photo")
            }

        case .fileURL:
            if let fileURL = item.fileURL {
                filePreview(fileURL)
            } else {
                unavailablePreview("无法读取文件", systemImage: "doc")
            }

        case .unknown:
            unavailablePreview("暂不支持的剪贴板内容", systemImage: "questionmark.square")
        }
    }

    private func filePreview(_ fileURL: URL) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.04))

                if let fileThumbnail {
                    Image(nsImage: fileThumbnail)
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
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fileURL.lastPathComponent)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(fileURL.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } icon: {
                Image(nsImage: fileIcon(for: fileURL))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
        }
        .task(id: fileURL.path) {
            fileThumbnail = nil
            fileThumbnail = await FileThumbnailService.shared.thumbnail(
                for: fileURL
            )
        }
    }

    private var sourceApplicationName: String {
        item.sourceAppName.isEmpty ? "未知来源" : item.sourceAppName
    }

    private func fileIcon(for fileURL: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: fileURL.path)
    }

    private var sourceApplicationIcon: NSImage {
        guard !item.sourceBundleID.isEmpty,
              let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: item.sourceBundleID
              ) else {
            return NSImage(
                systemSymbolName: "app",
                accessibilityDescription: sourceApplicationName
            ) ?? NSImage()
        }

        return NSWorkspace.shared.icon(forFile: applicationURL.path)
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
