//
//  AppDelegate.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit
import SwiftUI
import ServiceManagement
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BrowserRouter", category: "AppDelegate")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    var statusBarController: StatusBarController!
    var browserManager: BrowserManager!
    var ruleStore: RuleStore!
    var urlRouter: URLRouter!
    var pickerWindow: FloatingPickerWindow?
    private var preferencesWindow: NSWindow?
    /// Shared state store — created at launch, reused for Preferences UI.
    private var store: AppStateStore!

    /// Convenience accessor — settings is always sourced from the store after init.
    private var settings: AppSettings { store.settings }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Boot up core services
        browserManager = BrowserManager()
        ruleStore = RuleStore()

        // Shared state store (loads rules, settings, browsers, clickStats)
        store = AppStateStore(ruleStore: ruleStore, browserManager: browserManager)

        // Apply saved language preference
        if !settings.language.isEmpty {
            UserDefaults.standard.set([settings.language], forKey: "AppleLanguages")
        }

        let rules = store.rules
        do {
            urlRouter = try URLRouter(rules: rules)
        } catch {
            logger.error("Failed to compile URL rules: \(error.localizedDescription)")
        }

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
        let matched = urlRouter?.match(url)
        let browserInstalled = matched.map { browserManager.browser(forId: $0.browserId) != nil } ?? false
        let action = RouteResolver.resolve(
            matchedRule: matched,
            browserInstalled: browserInstalled,
            defaultBehavior: settings.defaultBehavior,
            forceShowPicker: NSEvent.modifierFlags.contains(.command)
        )

        switch action {
        case .openBrowser(let browserId):
            openAndRecord(url: url, browserId: browserId, isIncognito: false)
        case .showPicker:
            showPicker(for: url)
        case .showWarning(let rule):
            showBrowserMissingAlert(for: url, rule: rule)
        case .doNothing:
            break
        }
    }

    private func showPicker(for url: URL) {
        showPicker(for: url, updatingRule: nil)
    }

    // MARK: - Browser Missing Alert

    private func showBrowserMissingAlert(for url: URL, rule: BrowserRule) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Browser Not Found", comment: "")
        alert.informativeText = String(
            format: NSLocalizedString(
                "Rule \"%@\" matched, but the browser (%@) is not installed.\n\nWould you like to choose another browser to open this URL?",
                comment: ""
            ),
            rule.pattern, rule.browserId
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Choose Browser", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showPicker(for: url, updatingRule: rule)
        }
    }

    /// Shows the browser picker. If `updatingRule` is provided, the selected browser also updates that rule.
    private func showPicker(for url: URL, updatingRule: BrowserRule?) {
        let cursorPosition = NSEvent.mouseLocation
        let browsers = store.visibleBrowsers
        let showQuickAdd = updatingRule == nil && settings.showQuickAddButton

        pickerWindow = FloatingPickerWindow(
            browsers: browsers,
            atPosition: cursorPosition,
            showQuickAdd: showQuickAdd,
            incognitoHoverEnabled: settings.incognitoHoverEnabled,
            incognitoHoverDelay: settings.incognitoHoverDelay,
            onSelect: { [weak self] browserId, isIncognito in
                guard let self else { return }
                self.openAndRecord(url: url, browserId: browserId, isIncognito: isIncognito)

                if let rule = updatingRule {
                    do {
                        var rules = try self.ruleStore.loadRules()
                        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                            rules[idx].browserId = browserId
                            try self.ruleStore.save(rules: rules)
                            self.reloadSettings()
                        }
                    } catch {
                        logger.error("Failed to update rule browser: \(error.localizedDescription)")
                    }
                }
            },
            onQuickAdd: { [weak self] in
                self?.pickerWindow?.showQuickAddSheet(for: url)
            },
            onRuleSaved: updatingRule == nil ? { [weak self] pattern, browserId in
                guard let self else { return }
                do {
                    var rules = try self.ruleStore.loadRules()
                    rules.append(BrowserRule(pattern: pattern, browserId: browserId))
                    try self.ruleStore.save(rules: rules)
                    self.reloadSettings()
                } catch {
                    logger.error("Failed to save quick-add rule: \(error.localizedDescription)")
                }
                self.openAndRecord(url: url, browserId: browserId, isIncognito: false)
            } : nil
        )
        pickerWindow?.show()
    }

    /// Opens a URL in the specified browser and records the click.
    private func openAndRecord(url: URL, browserId: String, isIncognito: Bool) {
        if isIncognito {
            browserManager.openIncognito(url: url, browserId: browserId)
        } else {
            browserManager.open(url: url, browserId: browserId)
        }
        ruleStore.recordClick(browserId: browserId)
    }

    // MARK: - Settings Reload

    @objc private func reloadSettings() {
        store.load()  // single source: loads rules, settings, browsers, clickStats
        do {
            try urlRouter?.update(rules: store.rules)
        } catch {
            logger.error("Failed to recompile URL rules: \(error.localizedDescription)")
        }
        syncLaunchAtLogin()
        statusBarController.update(settings: settings)
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
        window.title = NSLocalizedString("BrowserRouter Settings", comment: "")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(UIConstants.preferencesSize)
        window.setFrameAutosaveName("PreferencesWindow")
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
