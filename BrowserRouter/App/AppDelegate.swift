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

        // Build main menu bar (LSUIElement apps need this for Edit menu support)
        setupMainMenu()

        // SwiftUI sheets swallow Edit key equivalents (Cmd+C/V/X/A/Z).
        // Intercept keyDown and send the action directly to the first responder.
        // Note: this monitor lives for the entire app lifetime (LSUIElement app).
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            let action: Selector?
            switch (event.charactersIgnoringModifiers, flags) {
            case ("c", .command): action = #selector(NSText.copy(_:))
            case ("v", .command): action = #selector(NSText.paste(_:))
            case ("x", .command): action = #selector(NSText.cut(_:))
            case ("a", .command): action = #selector(NSResponder.selectAll(_:))
            case ("z", [.command, .shift]): action = Selector(("redo:"))
            case ("z", .command): action = Selector(("undo:"))
            default: action = nil
            }

            if let action, NSApp.sendAction(action, to: nil, from: nil) {
                return nil
            }
            return event
        }

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
        let defaultBrowserInstalled: Bool = {
            if case .openInBrowser(let id) = settings.defaultBehavior {
                return browserManager.browser(forId: id) != nil
            }
            return true  // irrelevant for showPicker / doNothing
        }()
        let action = RouteResolver.resolve(
            matchedRule: matched,
            browserInstalled: browserInstalled,
            defaultBehavior: settings.defaultBehavior,
            defaultBrowserInstalled: defaultBrowserInstalled,
            forceShowPicker: NSEvent.modifierFlags.contains(.command)
        )

        switch action {
        case .openBrowser(let browserId):
            openAndRecord(url: url, browserId: browserId, isIncognito: false)
        case .showPicker:
            showPicker(for: url)
        case .showWarning(let rule):
            showBrowserMissingAlert(for: url, rule: rule)
        case .showDefaultBrowserWarning(let browserId):
            showDefaultBrowserMissingAlert(for: url, browserId: browserId)
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

    // MARK: - Default Browser Missing Alert

    private func showDefaultBrowserMissingAlert(for url: URL, browserId: String) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Default Browser Not Found", comment: "")
        alert.informativeText = String(
            format: NSLocalizedString(
                "The default fallback browser \"%@\" is no longer installed.\n\nWould you like to choose a replacement browser?",
                comment: ""
            ),
            browserId
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Choose Browser", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showDefaultBrowserPicker(for: url)
        }
    }

    /// Shows the browser picker for the default-browser-missing scenario.
    /// When the user picks a browser, opens the URL AND updates defaultBehavior setting.
    private func showDefaultBrowserPicker(for url: URL) {
        let cursorPosition = NSEvent.mouseLocation
        let browsers = store.visibleBrowsers

        pickerWindow = FloatingPickerWindow(
            browsers: browsers,
            atPosition: cursorPosition,
            showQuickAdd: false,
            incognitoHoverEnabled: settings.incognitoHoverEnabled,
            incognitoHoverDelay: settings.incognitoHoverDelay,
            onSelect: { [weak self] browserId, isIncognito in
                guard let self else { return }
                self.openAndRecord(url: url, browserId: browserId, isIncognito: isIncognito)

                // Update defaultBehavior to use the new browser
                var updatedSettings = self.settings
                updatedSettings.defaultBehavior = .openInBrowser(browserId)
                self.ruleStore.save(settings: updatedSettings)
                self.reloadSettings()
            },
            onQuickAdd: { },
            onRuleSaved: nil
        )
        pickerWindow?.show()
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
        let hostingController = UndoableHostingController(rootView: prefsView, undoManager: stateStore.undoManager)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("BrowserRouter Settings", comment: "")
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(UIConstants.preferencesSize)
        window.minSize = UIConstants.preferencesMinSize
        window.setFrameAutosaveName("PreferencesWindow")
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.preferencesWindow = window
    }

    // MARK: - Main Menu Bar

    /// Builds the standard NSMenu menu bar for LSUIElement apps.
    /// Provides Edit menu (Cmd+C/V/X/A/Z) and Window menu for TextFields.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: NSLocalizedString("About BrowserRouter", comment: ""),
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: NSLocalizedString("Settings…", comment: ""),
                                      action: #selector(openPreferencesWindow),
                                      keyEquivalent: ",")
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: NSLocalizedString("Quit BrowserRouter", comment: ""),
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: NSLocalizedString("Edit", comment: ""))
        // Note: undo:/redo: selectors use string construction because AppKit's
        // UndoManager dispatches these via the responder chain with no public @objc
        // method available for #selector. The double-parentheses silence the compiler warning.
        editMenu.addItem(withTitle: NSLocalizedString("Undo", comment: ""),
                         action: Selector(("undo:")),
                         keyEquivalent: "z")
        let redoItem = NSMenuItem(title: NSLocalizedString("Redo", comment: ""),
                                  action: Selector(("redo:")),
                                  keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: NSLocalizedString("Cut", comment: ""),
                         action: #selector(NSText.cut(_:)),
                         keyEquivalent: "x")
        editMenu.addItem(withTitle: NSLocalizedString("Copy", comment: ""),
                         action: #selector(NSText.copy(_:)),
                         keyEquivalent: "c")
        editMenu.addItem(withTitle: NSLocalizedString("Paste", comment: ""),
                         action: #selector(NSText.paste(_:)),
                         keyEquivalent: "v")
        editMenu.addItem(withTitle: NSLocalizedString("Select All", comment: ""),
                         action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: NSLocalizedString("Window", comment: ""))
        windowMenu.addItem(withTitle: NSLocalizedString("Minimize", comment: ""),
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        let closeItem = NSMenuItem(title: NSLocalizedString("Close", comment: ""),
                                   action: #selector(NSWindow.performClose(_:)),
                                   keyEquivalent: "w")
        windowMenu.addItem(closeItem)
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
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

// MARK: - UndoableHostingController

/// NSHostingController subclass that provides a custom UndoManager.
/// This lets the Edit ▸ Undo/Redo menu items connect to AppStateStore's UndoManager
/// via the responder chain.
final class UndoableHostingController<Content: View>: NSHostingController<Content> {
    private let customUndoManager: UndoManager

    init(rootView: Content, undoManager: UndoManager) {
        self.customUndoManager = undoManager
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var undoManager: UndoManager? { customUndoManager }
}
