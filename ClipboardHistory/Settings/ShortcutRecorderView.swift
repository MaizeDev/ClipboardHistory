//
//  ShortcutRecorderView.swift
//  ClipboardHistory
//

import AppKit
import KeyboardShortcuts
import SwiftUI

/// 自定义快捷键录制控件。
///
/// 没有直接使用 KeyboardShortcuts 自带的 `Recorder`，原因是它把录制状态
/// 绑在搜索框的编辑状态和窗口第一响应者上：设置窗口关闭再打开后，搜索框
/// 可能仍停留在文本编辑状态，此时输入的字母会变成普通文本，组合键则被
/// 系统直接吞掉（表现为“怎么按组合键都只有提示音”）。
///
/// 这里的录制状态完全由点击按钮开始/结束，用本地事件监视器抓按键，因此
/// 不依赖窗口第一响应者，窗口反复开关也不会失效。
struct ShortcutRecorderField: NSViewRepresentable {

    let shortcut: EditableClipboardShortcut

    /// 校验失败时把原因交给 SwiftUI 行内显示，避免控件自身高度变化导致整页跳动。
    let onMessage: (String?) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderView {
        ShortcutRecorderView(shortcut: shortcut, onMessage: onMessage)
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.update(shortcut: shortcut, onMessage: onMessage)
    }
}

@MainActor
final class ShortcutRecorderView: NSView {

    private var shortcut: EditableClipboardShortcut
    private var onMessage: ((String?) -> Void)?

    private let recordButton = NSButton()
    private let clearButton = NSButton()

    private var isRecording = false
    private var eventMonitor: Any?
    private var windowResignObserver: NSObjectProtocol?

    init(
        shortcut: EditableClipboardShortcut,
        onMessage: @escaping (String?) -> Void
    ) {
        self.shortcut = shortcut
        self.onMessage = onMessage
        super.init(frame: .zero)

        configureSubviews()
        refreshDisplay()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }

        if let windowResignObserver {
            NotificationCenter.default.removeObserver(windowResignObserver)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window == nil {
            stopRecording()
        }
    }

    func update(
        shortcut: EditableClipboardShortcut,
        onMessage: @escaping (String?) -> Void
    ) {
        self.shortcut = shortcut
        self.onMessage = onMessage
        refreshDisplay()
    }

    private func configureSubviews() {
        recordButton.bezelStyle = .rounded
        recordButton.controlSize = .regular
        recordButton.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        recordButton.alignment = .center
        recordButton.target = self
        recordButton.action = #selector(toggleRecording)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        recordButton.setContentHuggingPriority(.defaultLow, for: .horizontal)

        clearButton.bezelStyle = .inline
        clearButton.isBordered = false
        clearButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "清除快捷键"
        )
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        clearButton.toolTip = "清除快捷键"
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let buttonRow = NSStackView(views: [recordButton, clearButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 6
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        addSubview(buttonRow)

        NSLayoutConstraint.activate([
            buttonRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            buttonRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            buttonRow.topAnchor.constraint(equalTo: topAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 190)
        ])

        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    private func refreshDisplay() {
        if isRecording {
            return
        }

        let currentShortcut = KeyboardShortcuts.getShortcut(for: shortcut.name)

        if let currentShortcut {
            recordButton.title = currentShortcut.description
            clearButton.isHidden = false
        } else {
            recordButton.title = "点击设置快捷键"
            clearButton.isHidden = true
        }
    }

    private func showMessage(_ message: String) {
        onMessage?(message)
    }

    private func hideMessage() {
        onMessage?(nil)
    }

    @objc
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else {
            return
        }

        isRecording = true
        hideMessage()
        recordButton.title = "请按下快捷键…"
        clearButton.isHidden = true

        // 录制期间暂停已注册的全局快捷键，避免按到旧快捷键时把历史浮窗打开。
        KeyboardShortcuts.disable(EditableClipboardShortcut.allCases.map(\.name))

        windowResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopRecording()
            }
        }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self else {
                return event
            }

            return self.handle(event)
        }
    }

    private func stopRecording() {
        guard isRecording else {
            return
        }

        isRecording = false

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        if let windowResignObserver {
            NotificationCenter.default.removeObserver(windowResignObserver)
            self.windowResignObserver = nil
        }

        KeyboardShortcuts.enable(EditableClipboardShortcut.allCases.map(\.name))

        refreshDisplay()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard isRecording else {
            return event
        }

        if event.type != .keyDown {
            // 录制时点到控件外面就结束录制，避免一直抢走键盘事件。
            let point = convert(event.locationInWindow, from: nil)

            if event.window !== window || !bounds.insetBy(dx: -4, dy: -4).contains(point) {
                stopRecording()
                return event
            }

            return event
        }

        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])

        if modifiers.isEmpty {
            // Esc / Delete 的清除与取消操作。
            switch event.keyCode {
            case 53: // Esc
                stopRecording()
                return nil

            case 51, 117: // Delete / Forward Delete
                apply(nil)
                stopRecording()
                return nil

            default:
                showMessage("请同时按下 ⌘、⌥ 或 ⌃ 等修饰键。")
                return nil
            }
        }

        guard let newShortcut = KeyboardShortcuts.Shortcut(event: event) else {
            showMessage("无法识别这个按键组合，请换一组。")
            return nil
        }

        switch shortcut.validate(newShortcut) {
        case .allow:
            apply(newShortcut)
            stopRecording()
            return nil

        case .disallow(let reason):
            showMessage(reason)
            return nil
        }
    }

    private func apply(_ newShortcut: KeyboardShortcuts.Shortcut?) {
        KeyboardShortcuts.setShortcut(newShortcut, for: shortcut.name)
        refreshDisplay()
    }

    @objc
    private func clearShortcut() {
        apply(nil)
    }
}
