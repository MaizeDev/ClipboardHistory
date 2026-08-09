#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("用法：make_dmg_background.swift <输出 PNG 路径>\n".utf8)
    )
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 660, height: 420)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("无法创建 DMG 背景画布")
}

bitmap.size = canvasSize

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("无法创建 DMG 背景绘图环境")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let canvas = NSRect(origin: .zero, size: canvasSize)

let backgroundGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.84, green: 0.91, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.93, green: 0.95, blue: 1.00, alpha: 1),
    NSColor(calibratedRed: 0.96, green: 0.89, blue: 0.98, alpha: 1)
])
backgroundGradient?.draw(in: canvas, angle: -12)

NSColor.white.withAlphaComponent(0.28).setFill()
NSBezierPath(ovalIn: NSRect(x: -90, y: 220, width: 360, height: 280)).fill()

NSColor(
    calibratedRed: 0.25,
    green: 0.73,
    blue: 0.98,
    alpha: 0.10
).setFill()
NSBezierPath(ovalIn: NSRect(x: 430, y: -70, width: 300, height: 260)).fill()

let panelRect = canvas.insetBy(dx: 22, dy: 22)
let panel = NSBezierPath(
    roundedRect: panelRect,
    xRadius: 28,
    yRadius: 28
)
NSColor.white.withAlphaComponent(0.42).setFill()
panel.fill()
NSColor.white.withAlphaComponent(0.72).setStroke()
panel.lineWidth = 1
panel.stroke()

let arrowShadow = NSShadow()
arrowShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
arrowShadow.shadowBlurRadius = 8
arrowShadow.shadowOffset = NSSize(width: 0, height: -3)
arrowShadow.set()

let arrowColor = NSColor(
    calibratedRed: 0.18,
    green: 0.42,
    blue: 0.90,
    alpha: 0.82
)
arrowColor.setStroke()
arrowColor.setFill()

let arrowLine = NSBezierPath()
arrowLine.move(to: NSPoint(x: 278, y: 228))
arrowLine.line(to: NSPoint(x: 369, y: 228))
arrowLine.lineWidth = 12
arrowLine.lineCapStyle = .round
arrowLine.stroke()

let arrowHead = NSBezierPath()
arrowHead.move(to: NSPoint(x: 357, y: 249))
arrowHead.line(to: NSPoint(x: 387, y: 228))
arrowHead.line(to: NSPoint(x: 357, y: 207))
arrowHead.close()
arrowHead.fill()

NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let installTitle = NSAttributedString(
    string: "拖到“应用程序”完成安装",
    attributes: [
        .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
        .foregroundColor: NSColor(
            calibratedRed: 0.16,
            green: 0.20,
            blue: 0.34,
            alpha: 0.86
        ),
        .paragraphStyle: paragraphStyle
    ]
)
installTitle.draw(
    in: NSRect(x: 90, y: 66, width: 480, height: 28)
)

let subtitle = NSAttributedString(
    string: "Drag to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .medium),
        .foregroundColor: NSColor(
            calibratedRed: 0.24,
            green: 0.29,
            blue: 0.43,
            alpha: 0.48
        ),
        .paragraphStyle: paragraphStyle
    ]
)
subtitle.draw(
    in: NSRect(x: 90, y: 45, width: 480, height: 18)
)

NSGraphicsContext.restoreGraphicsState()

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("无法输出 DMG 背景 PNG")
}

try pngData.write(to: outputURL, options: .atomic)
