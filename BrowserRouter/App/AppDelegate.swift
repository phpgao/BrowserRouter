//
//  AppDelegate.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController!
    var browserManager: BrowserManager!
    var ruleStore: RuleStore!
    var urlRouter: URLRouter!
    var settings: AppSettings!
    var pickerWindow: FloatingPickerWindow?
    private var preferencesWindow: NSWindow?
    /// Shared state store — created at launch, reused for Preferences UI.
    private var store: AppStateStore!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Boot up core services
        browserManager = BrowserManager()
        ruleStore = RuleStore()

        settings = ruleStore.loadSettings()

        // Apply saved language preference
        if !settings.language.isEmpty {
            UserDefaults.standard.set([settings.language], forKey: "AppleLanguages")
        }

        let rules = (try? ruleStore.loadRules()) ?? []
        urlRouter = try? URLRouter(rules: rules)

        // Shared state store
        store = AppStateStore(ruleStore: ruleStore, browserManager: browserManager)

        // Sync launch-at-login state
        syncLaunchAtLogin()

        // Status bar
        statusBarController = StatusBarController(
            browserManager: browserManager,
            settings: settings,
            onSettingsChanged: { [weak self] updatedSettings in
                self?.ruleStore.save(settings: updatedSettings)
                self?.reloadSettings()
            }
        )

        // Listen for rule/settings changes from Preferences UI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadSettings),
            name: .settingsDidChange,
            object: nil
        )

        // Listen for Preferences open request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferencesWindow),
            name: .openPreferences,
            object: nil
        )
    }

    // MARK: - URL Handling (core routing logic)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            route(url: url)
        }
    }

    private func route(url: URL) {
        // Hold ⌘ to force browser picker regardless of rules
        if NSEvent.modifierFlags.contains(.command) {
            showPicker(for: url)
            return
        }

        // 1. Try rule match
        if let rule = urlRouter?.match(url) {
            let opened = browserManager.open(url: url, browserId: rule.browserId)
            if opened {
                ruleStore.recordClick(browserId: rule.browserId)
                return
            }
            // Browser from rule not installed — fall through to fallback
        }

        // 2. No rule match (or matched browser not installed) — use fallback behavior
        switch settings.defaultBehavior {
        case .showPicker:
            showPicker(for: url)
        case .openInBrowser(let browserId):
            browserManager.open(url: url, browserId: browserId)
            ruleStore.recordClick(browserId: browserId)
        case .doNothing:
            break  // Intentionally discard
        }
    }

    private func showPicker(for url: URL) {
        let cursorPosition = NSEvent.mouseLocation
        let browsers = store.visibleBrowsers
        let showQuickAdd = settings.showQuickAddButton

        pickerWindow = FloatingPickerWindow(
            browsers: browsers,
            atPosition: cursorPosition,
            showQuickAdd: showQuickAdd,
            incognitoHoverEnabled: settings.incognitoHoverEnabled,
            incognitoHoverDelay: settings.incognitoHoverDelay,
            onSelect: { [weak self] browserId, isIncognito in
                if isIncognito {
                    self?.browserManager.openIncognito(url: url, browserId: browserId)
                } else {
                    self?.browserManager.open(url: url, browserId: browserId)
                }
                self?.ruleStore.recordClick(browserId: browserId)
            },
            onQuickAdd: { [weak self] in
                self?.pickerWindow?.showQuickAddSheet(for: url)
            },
            onRuleSaved: { [weak self] pattern, browserId in
                guard let self else { return }
                var rules = (try? self.ruleStore.loadRules()) ?? []
                rules.append(BrowserRule(pattern: pattern, browserId: browserId))
                try? self.ruleStore.save(rules: rules)
                self.reloadSettings()
                // Open the URL with the browser the user just chose for this rule
                self.browserManager.open(url: url, browserId: browserId)
                self.ruleStore.recordClick(browserId: browserId)
            }
        )
        pickerWindow?.show()
    }

    // MARK: - Settings Reload

    @objc private func reloadSettings() {
        settings = ruleStore.loadSettings()
        let rules = (try? ruleStore.loadRules()) ?? []
        try? urlRouter?.update(rules: rules)
        syncLaunchAtLogin()
        statusBarController.update(settings: settings)
        store.load()
    }

    @objc private func openPreferencesWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let preferencesWindow, preferencesWindow.isVisible {
            preferencesWindow.makeKeyAndOrderFront(nil)
            return
        }

        let stateStore = store!

        let prefsView = PreferencesView(store: stateStore)
        let hostingController = NSHostingController(rootView: prefsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("BrowserRouter Preferences", comment: "")
        window.styleMask = [.titled, .closable]
        window.setContentSize(UIConstants.preferencesSize)
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.preferencesWindow = window
    }

    private func syncLaunchAtLogin() {
        // Only call SMAppService when the user explicitly wants login item.
        // Calling unregister() on a non-registered app with local signing triggers
        // "Operation not permitted" — skip it when launchAtLogin is false.
        guard settings.launchAtLogin else { return }
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Non-fatal — login item registration may fail under local signing
            print("Launch at login registration failed: \(error)")
        }
    }
}

extension Notification.Name {
    static let settingsDidChange = Notification.Name("BrowserRouterSettingsDidChange")
}
