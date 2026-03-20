//
//  StatusBarController.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit
import Sparkle

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let browserManager: BrowserManager
    private var settings: AppSettings
    private let onSettingsChanged: (AppSettings) -> Void
    let updaterController: SPUStandardUpdaterController

    init(browserManager: BrowserManager, settings: AppSettings, onSettingsChanged: @escaping (AppSettings) -> Void) {
        self.browserManager = browserManager
        self.settings = settings
        self.onSettingsChanged = onSettingsChanged
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
        updaterController.updater.automaticallyChecksForUpdates = settings.autoCheckUpdates
        setupStatusItem()
    }

    func update(settings: AppSettings) {
        self.settings = settings
        updaterController.updater.automaticallyChecksForUpdates = settings.autoCheckUpdates
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

        // Check for Updates
        let updateItem = NSMenuItem(title: NSLocalizedString("Check for Updates…", comment: ""), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

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
        let alert = NSAlert()
        alert.messageText = "BrowserRouter"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        alert.informativeText = """
        Version \(version) (\(build))

        \(NSLocalizedString("A lightweight macOS app that routes URLs to different browsers based on rules.", comment: ""))

        Copyright © 2026 jimmy. All rights reserved. License GPLv3.
        """
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            alert.icon = appIcon
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
