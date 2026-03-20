//
//  FloatingPickerWindow.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit
import SwiftUI

/// A custom NSPanel subclass that accepts first mouse click
/// even when the app is not active (required for LSUIElement apps).
private class ClickThroughPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Custom NSHostingView that accepts first mouse — allows clicking buttons
/// without first activating the panel (NSView-level override required by AppKit).
private class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Transparent floating browser picker that appears at cursor position.
final class FloatingPickerWindow {

    private var panel: NSPanel?
    private let browsers: [Browser]
    private let position: NSPoint
    private let showQuickAdd: Bool
    private let incognitoHoverEnabled: Bool
    private let incognitoHoverDelay: Double
    private let onSelect: (String, Bool) -> Void  // (browserId, isIncognito)
    private let onQuickAdd: () -> Void

    // Track event monitors for cleanup
    private nonisolated(unsafe) var localMonitor: Any?
    private nonisolated(unsafe) var globalMonitor: Any?

    private var quickAddPanel: NSPanel?
    private var onRuleSaved: ((String, String) -> Void)?

    init(browsers: [Browser], atPosition: NSPoint, showQuickAdd: Bool,
         incognitoHoverEnabled: Bool = true, incognitoHoverDelay: Double = 1.0,
         onSelect: @escaping (String, Bool) -> Void, onQuickAdd: @escaping () -> Void,
         onRuleSaved: ((String, String) -> Void)? = nil) {
        self.browsers = browsers
        self.position = atPosition
        self.showQuickAdd = showQuickAdd
        self.incognitoHoverEnabled = incognitoHoverEnabled
        self.incognitoHoverDelay = incognitoHoverDelay
        self.onSelect = onSelect
        self.onQuickAdd = onQuickAdd
        self.onRuleSaved = onRuleSaved
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
    }

    func show() {
        let pickerView = BrowserPickerView(
            browsers: browsers,
            showQuickAdd: showQuickAdd,
            incognitoHoverEnabled: incognitoHoverEnabled,
            incognitoHoverDelay: incognitoHoverDelay,
            onSelect: { [weak self] browserId, isIncognito in
                self?.onSelect(browserId, isIncognito)
                self?.dismiss()
            },
            onQuickAdd: { [weak self] in
                self?.onQuickAdd()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        // Calculate panel size
        let itemCount = browsers.count + (showQuickAdd ? 1 : 0)
        let contentWidth = CGFloat(itemCount) * 78 + 40  // 70pt per item + spacing + padding
        let panelSize = NSSize(width: max(contentWidth, 140) + 24, height: 130)

        // Create panel using custom subclass that accepts first-mouse
        let panel = ClickThroughPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false

        // Visual effect view for real dock-like frosted glass
        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: panelSize))
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = UIConstants.pickerCornerRadius
        visualEffect.layer?.masksToBounds = true

        // SwiftUI content on top of the vibrancy layer
        let hostingView = ClickThroughHostingView(rootView: pickerView)
        hostingView.setFrameSize(panelSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        visualEffect.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        panel.contentView = visualEffect

        // Position at cursor, adjusting for screen edges
        var origin = position
        origin.x -= panelSize.width / 2
        origin.y -= panelSize.height / 2

        if let screen = NSScreen.main?.visibleFrame {
            origin.x = max(screen.minX, min(origin.x, screen.maxX - panelSize.width))
            origin.y = max(screen.minY, min(origin.y, screen.maxY - panelSize.height))
        }

        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel

        // Dismiss on Esc key
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }

        // Dismiss on click outside — use local monitor for clicks inside the panel too
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }
    }

    func dismiss() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil

        dismissQuickAdd()
        panel?.orderOut(nil)
        panel = nil
    }

    func showQuickAddSheet(for url: URL) {
        guard let panel else { return }

        let sheetView = QuickAddRuleSheet(
            url: url,
            browsers: browsers,
            onSave: { [weak self] pattern, browserId in
                self?.onRuleSaved?(pattern, browserId)
                self?.dismissQuickAdd()
                self?.dismiss()
            },
            onCancel: { [weak self] in
                self?.dismissQuickAdd()
            }
        )

        let hostingView = NSHostingView(rootView: sheetView)
        let sheetSize = NSSize(width: 320, height: 260)
        hostingView.setFrameSize(sheetSize)

        let quickPanel = ClickThroughPanel(
            contentRect: NSRect(origin: .zero, size: sheetSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        quickPanel.title = NSLocalizedString("Quick Add Rule", comment: "")
        quickPanel.contentView = hostingView
        quickPanel.level = .popUpMenu + 1
        quickPanel.hidesOnDeactivate = false

        var origin = panel.frame.origin
        origin.x += (panel.frame.width - sheetSize.width) / 2
        origin.y -= sheetSize.height + 8
        quickPanel.setFrameOrigin(origin)
        quickPanel.makeKeyAndOrderFront(nil)

        self.quickAddPanel = quickPanel
    }

    private func dismissQuickAdd() {
        quickAddPanel?.orderOut(nil)
        quickAddPanel = nil
    }
}
