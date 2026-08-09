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
}
