//
//  HistoryPanelPlacement.swift
//  ClipboardHistory
//

import AppKit

enum HistoryPanelPlacement {

    static func screenIndex(
        containing point: NSPoint,
        screenFrames: [NSRect]
    ) -> Int? {
        screenFrames.firstIndex { frame in
            frame.contains(point)
        }
    }

    static func centeredFrame(
        panelSize: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        NSRect(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    /// 在屏幕中央的基础上加上用户拖动留下的偏移，
    /// 并保证结果完全落在可见区域内（换了显示器或分辨率也不会跑出屏幕）。
    static func frame(
        panelSize: NSSize,
        visibleFrame: NSRect,
        offset: CGSize
    ) -> NSRect {
        var frame = centeredFrame(
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        frame.origin.x += offset.width
        frame.origin.y += offset.height

        return clamped(frame, in: visibleFrame)
    }

    static func clamped(
        _ frame: NSRect,
        in bounds: NSRect
    ) -> NSRect {
        var result = frame

        let maxX = max(bounds.minX, bounds.maxX - frame.width)
        let maxY = max(bounds.minY, bounds.maxY - frame.height)

        result.origin.x = min(max(frame.origin.x, bounds.minX), maxX)
        result.origin.y = min(max(frame.origin.y, bounds.minY), maxY)

        return result
    }
}
