//
//  HistoryItemCard.swift
//  ClipboardHistory
//

import AppKit
import SwiftUI

struct HistoryItemCard: View {

    let item: HistoryItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            metadata
            contentPreview
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

            Text(item.timestamp, style: .relative)
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
                    Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
            } else {
                unavailablePreview("无法读取文件", systemImage: "doc")
            }

        case .unknown:
            unavailablePreview("暂不支持的剪贴板内容", systemImage: "questionmark.square")
        }
    }

    private var sourceApplicationName: String {
        item.sourceAppName.isEmpty ? "未知来源" : item.sourceAppName
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
