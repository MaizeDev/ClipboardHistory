//
//  HistoryPanel.swift
//  ClipboardHistory
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class HistoryPanel: NSPanel {

    private static let panelSize = NSSize(
        width: HistoryPanelLayout.width,
        height: HistoryPanelLayout.height
    )
    private let viewState = HistoryPanelViewState()

    private let onDelete: (HistoryItem) -> Void
    private let onTogglePin: (HistoryItem) -> Void
    private let onToggleFavorite: (HistoryItem) -> Void
    private let onChoose: (HistoryItem, ClipboardCopyMode) -> Bool
    private let preferences: AppPreferences

    init(
        modelContainer: ModelContainer,
        preferences: AppPreferences,
        onDelete: @escaping (HistoryItem) -> Void,
        onTogglePin: @escaping (HistoryItem) -> Void,
        onToggleFavorite: @escaping (HistoryItem) -> Void,
        onChoose: @escaping (HistoryItem, ClipboardCopyMode) -> Bool
    ) {
        self.preferences = preferences
        self.onDelete = onDelete
        self.onTogglePin = onTogglePin
        self.onToggleFavorite = onToggleFavorite
        self.onChoose = onChoose

        super.init(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [
                .borderless,
                .nonactivatingPanel,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        configureWindow()
        configureContent(modelContainer: modelContainer)
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           let fieldEditor = firstResponder as? NSTextView {
            if fieldEditor.hasMarkedText()
                || shouldForwardDeletionToSearchField(
                    event,
                    fieldEditor: fieldEditor
                ) {
                super.sendEvent(event)
                return
            }
        }

        guard event.type == .keyDown,
              let command = HistoryPanelKeyboard.command(
                keyCode: event.keyCode,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifierFlags: event.modifierFlags
              ) else {
            super.sendEvent(event)
            return
        }

        guard !event.isARepeat || command.allowsKeyRepeat else {
            return
        }

        viewState.send(command)
    }

    private func shouldForwardDeletionToSearchField(
        _ event: NSEvent,
        fieldEditor: NSTextView
    ) -> Bool {
        let deleteKeyCodes: Set<UInt16> = [51, 117]

        return deleteKeyCodes.contains(event.keyCode)
            && !fieldEditor.string.isEmpty
    }

    func show() {
        guard !isVisible else {
            makeKey()
            requestSearchFocus()
            return
        }

        positionOnPointerScreen()
        makeKeyAndOrderFront(nil)
        requestSearchFocus()
    }

    func hide() {
        orderOut(nil)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    override func resignKey() {
        super.resignKey()
        hide()
    }

    private func configureWindow() {
        title = "剪贴板历史"
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]
    }

    private func configureContent(modelContainer: ModelContainer) {
        let rootView = HistoryPanelContentView(
            viewState: viewState,
            preferences: preferences,
            onDelete: onDelete,
            onTogglePin: onTogglePin,
            onToggleFavorite: onToggleFavorite,
            onChoose: onChoose,
            onClose: { [weak self] in
                self?.hide()
            }
        )
        .modelContainer(modelContainer)

        contentView = NSHostingView(rootView: rootView)
    }

    private func positionOnPointerScreen() {
        let screens = NSScreen.screens
        let pointerLocation = NSEvent.mouseLocation
        let screenIndex = HistoryPanelPlacement.screenIndex(
            containing: pointerLocation,
            screenFrames: screens.map(\.frame)
        )
        let targetScreen = screenIndex.map { screens[$0] }
            ?? NSScreen.main
            ?? screens.first

        guard let targetScreen else {
            center()
            return
        }

        let targetFrame = HistoryPanelPlacement.centeredFrame(
            panelSize: Self.panelSize,
            visibleFrame: targetScreen.visibleFrame
        )

        setFrame(targetFrame, display: false)
    }

    private func requestSearchFocus() {
        Task { @MainActor [weak self] in
            await Task.yield()

            guard let self, self.isVisible else {
                return
            }

            self.viewState.requestSearchFocus()
        }
    }
}
