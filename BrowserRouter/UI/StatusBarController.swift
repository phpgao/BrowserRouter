//
//  StatusBarController.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let browserManager: BrowserManager
    private var settings: AppSettings
    private let onSettingsChanged: (AppSettings) -> Void

    init(browserManager: BrowserManager, settings: AppSettings, onSettingsChanged: @escaping (AppSettings) -> Void) {
        self.browserManager = browserManager
        self.settings = settings
        self.onSettingsChanged = onSettingsChanged
        super.init()
        setupStatusItem()
    }

    func update(settings: AppSettings) {
        self.settings = settings
        rebuildMenu()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let icon = NSImage(named: "StatusBarIcon")
            icon?.isTemplate = true  // Auto-adapts to Dark Mode
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
        }

        rebuildMenu()
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Settings
        let prefsItem = NSMenuItem(title: NSLocalizedString("Open Settings…", comment: ""), action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        // Default browser
        let isDefault = BrowserManager.isDefaultBrowser()
        let defaultItem = NSMenuItem(title: NSLocalizedString("Default Browser", comment: ""), action: isDefault ? nil : #selector(setAsDefaultBrowser), keyEquivalent: "")
        defaultItem.target = self
        defaultItem.state = isDefault ? .on : .off
        defaultItem.isEnabled = !isDefault
        menu.addItem(defaultItem)

        // Launch at login
        let loginItem = NSMenuItem(title: NSLocalizedString("Launch at Login", comment: ""), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = settings.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // About
        let aboutItem = NSMenuItem(title: NSLocalizedString("About", comment: ""), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: NSLocalizedString("Quit BrowserRouter", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    // MARK: - Actions

    @objc private func openPreferences() {
        NotificationCenter.default.post(name: .openPreferences, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(
                string: NSLocalizedString("A lightweight macOS app that routes URLs to different browsers based on rules.", comment: ""),
                attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
            )
        ])
    }

    @objc private func setAsDefaultBrowser() {
        BrowserManager.setAsDefaultBrowser { [weak self] success in
            if !success {
                BrowserManager.showDefaultBrowserFailureAlert()
            }
            self?.rebuildMenu()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        settings.launchAtLogin.toggle()
        onSettingsChanged(settings)
        rebuildMenu()
    }
}
