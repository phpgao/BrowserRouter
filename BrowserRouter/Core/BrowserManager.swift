//
//  BrowserManager.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import AppKit

/// Detects installed browsers and launches URLs in a specific browser.
final class BrowserManager {

    // Known mainstream browser bundle IDs and their display names
    private static let knownBrowsers: [(id: String, name: String)] = [
        ("com.apple.Safari",            "Safari"),
        ("com.google.Chrome",           "Google Chrome"),
        ("com.google.Chrome.canary",    "Google Chrome Canary"),
        ("org.chromium.Chromium",       "Chromium"),
        ("org.mozilla.firefox",         "Firefox"),
        ("com.microsoft.edgemac",       "Microsoft Edge"),
        ("company.thebrowser.Browser",  "Arc"),
        ("com.brave.Browser",           "Brave Browser"),
        ("com.operasoftware.Opera",     "Opera"),
        ("com.operasoftware.OperaGX",   "Opera GX"),
        ("com.vivaldi.Vivaldi",         "Vivaldi"),
        ("ru.yandex.desktop.yandex-browser", "Yandex Browser"),
        ("com.duckduckgo.macos.browser", "DuckDuckGo"),
        ("org.torproject.torbrowser",   "Tor Browser"),
        // Chinese browsers
        ("org.uc.UC",                   "UC Browser"),
        ("com.quark.desktop",            "Quark Browser"),
        ("net.qihoo.360browser",        "360"),
        ("com.kagi.kagimacOS",          "Orion"),
    ]

    /// All installed browsers detected on this machine.
    private(set) var installedBrowsers: [Browser] = []

    /// Monitors /Applications for changes to auto-refresh browser list.
    private var applicationsMonitor: DispatchSourceFileSystemObject?
    private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        startMonitoringApplications()
    }

    deinit {
        applicationsMonitor?.cancel()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Re-scan for installed browsers.
    func refresh() {
        installedBrowsers = Self.knownBrowsers.compactMap { entry in
            guard let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: entry.id
            ) else { return nil }

            // Verify the app actually exists on disk (Launch Services cache may be stale)
            guard FileManager.default.fileExists(atPath: appURL.path) else { return nil }

            let bundle = Bundle(url: appURL)
            let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)

            return Browser(
                id: entry.id,
                name: entry.name,
                version: version,
                icon: icon
            )
        }
    }

    // MARK: - Applications Directory Monitoring

    private func startMonitoringApplications() {
        // 1. Monitor /Applications directory for file changes (install/uninstall)
        let fd = Darwin.open("/Applications", O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .link],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                // Delay slightly to let the install/uninstall finish
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Task { @MainActor in
                        self?.handleApplicationsChanged()
                    }
                }
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
            applicationsMonitor = source
        }

        // 2. Listen for NSWorkspace app launch/terminate notifications
        let ws = NSWorkspace.shared.notificationCenter
        let launchObs = ws.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleApplicationsChanged()
            }
        }
        let terminateObs = ws.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleApplicationsChanged()
            }
        }
        observers = [launchObs, terminateObs]
    }

    private func handleApplicationsChanged() {
        let oldIds = Set(installedBrowsers.map { $0.id })
        refresh()
        let newIds = Set(installedBrowsers.map { $0.id })
        if oldIds != newIds {
            NotificationCenter.default.post(name: .settingsDidChange, object: nil)
        }
    }

    /// Returns the Browser for a given bundle ID, or nil if not installed.
    func browser(forId id: String) -> Browser? {
        installedBrowsers.first { $0.id == id }
    }

    /// Opens the given URL in the specified browser.
    /// Returns true if the browser was found and launched; false if not installed.
    @discardableResult
    func open(url: URL, browserId: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: browserId
        ) else {
            showMissingBrowserAlert(browserId: browserId)
            return false
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appURL,
            configuration: config
        )
        return true
    }

    /// Opens the given URL in the specified browser's incognito/private mode.
    ///
    /// Incognito support by browser type:
    /// - **Chromium-based** (Chrome, Edge, Brave, Vivaldi, Opera, Yandex): launch executable with `--incognito`/`--inprivate`/`--private`
    /// - **Firefox**: launch via `open -a` with `-private-window` argument
    /// - **No CLI support** (Safari, Arc, DuckDuckGo, Quark, UC, 360, GNOME Web, Orion): falls back to normal open
    ///
    /// Returns true if the browser was found and launched; false if not installed.
    @discardableResult
    func openIncognito(url: URL, browserId: String) -> Bool {
        guard NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: browserId
        ) != nil else {
            showMissingBrowserAlert(browserId: browserId)
            return false
        }

        // Resolve the incognito launch strategy for this browser
        let strategy = Self.incognitoStrategy(for: browserId)

        switch strategy {
        case .chromium(let arg):
            return openChromiumIncognito(url: url, browserId: browserId, arg: arg)
        case .firefox:
            return openFirefoxPrivate(url: url, browserId: browserId)
        case .unsupported:
            // No CLI incognito support — open normally
            return open(url: url, browserId: browserId)
        }
    }

    // MARK: - Incognito Strategy

    /// Returns whether the given browser supports incognito/private mode via CLI.
    static func supportsIncognito(browserId: String) -> Bool {
        incognitoStrategy(for: browserId) != .unsupported
    }

    private enum IncognitoStrategy: Equatable {
        /// Chromium-based: launch binary with the given flag (e.g. --incognito, --inprivate, --private)
        case chromium(String)
        /// Firefox: use `open -a` with `-private-window`
        case firefox
        /// No known CLI incognito support — will fall back to normal open
        case unsupported
    }

    /// Maps a browser bundle ID to its incognito launch strategy.
    private static func incognitoStrategy(for browserId: String) -> IncognitoStrategy {
        switch browserId {
        // Chromium-based: --incognito
        case "com.google.Chrome", "com.google.Chrome.canary", "org.chromium.Chromium",
             "com.brave.Browser", "com.vivaldi.Vivaldi", "ru.yandex.desktop.yandex-browser":
            return .chromium("--incognito")

        // Edge: --inprivate
        case "com.microsoft.edgemac":
            return .chromium("--inprivate")

        // Opera: --private
        case "com.operasoftware.Opera", "com.operasoftware.OperaGX":
            return .chromium("--private")

        // Firefox / Tor Browser: -private-window
        case "org.mozilla.firefox", "org.torproject.torbrowser":
            return .firefox

        // No CLI incognito support:
        // Safari, Arc, DuckDuckGo, Quark, UC Browser, 360 Browser, 360 Speed, GNOME Web, Orion
        default:
            return .unsupported
        }
    }

    // MARK: - Incognito Helpers

    /// Chromium-based: launch the binary directly with incognito flag.
    /// This works regardless of whether the browser is already running.
    private func openChromiumIncognito(url: URL, browserId: String, arg: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: browserId
        ) else { return false }

        // Find the actual executable inside the .app bundle
        let bundle = Bundle(url: appURL)
        guard let executablePath = bundle?.executablePath else {
            // Fallback to open -na
            return openViaOpenCommand(appPath: appURL.path, url: url, arg: arg)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [arg, url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            // Fallback
            return openViaOpenCommand(appPath: appURL.path, url: url, arg: arg)
        }
    }

    /// Fallback: use `open -na` to force a new instance with args.
    private func openViaOpenCommand(appPath: String, url: URL, arg: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", appPath, "--args", arg, url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    /// Firefox / Tor Browser: -private-window works as an argument to the open command.
    private func openFirefoxPrivate(url: URL, browserId: String) -> Bool {
        guard let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: browserId
        ) else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appURL.path, "-n", "--args", "-private-window", url.absoluteString]
        do {
            try process.run()
            return true
        } catch {
            return open(url: url, browserId: browserId)
        }
    }

    // MARK: - Default Browser

    /// Checks whether BrowserRouter is the current default browser for HTTPS URLs.
    static func isDefaultBrowser() -> Bool {
        guard
            let url = URL(string: "https://example.com"),
            let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
            let bundleId = Bundle(url: appURL)?.bundleIdentifier
        else { return false }
        return bundleId == Bundle.main.bundleIdentifier
    }

    /// Sets BrowserRouter as the default browser for both HTTP and HTTPS schemes.
    /// Calls `completion` on the main queue with `true` on success, `false` on failure.
    static func setAsDefaultBrowser(completion: @escaping (Bool) -> Void) {
        guard let appURL = Bundle.main.bundleURL as URL? else {
            DispatchQueue.main.async { completion(false) }
            return
        }
        let lock = NSLock()
        var httpError: Error?
        var httpsError: Error?
        let group = DispatchGroup()

        group.enter()
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http") { error in
            lock.lock()
            httpError = error
            lock.unlock()
            group.leave()
        }
        group.enter()
        NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https") { error in
            lock.lock()
            httpsError = error
            lock.unlock()
            group.leave()
        }
        group.notify(queue: .main) {
            completion(httpError == nil && httpsError == nil)
        }
    }

    /// Shows a standard alert when setting default browser fails.
    static func showDefaultBrowserFailureAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Could Not Set Default Browser", comment: "")
        alert.informativeText = NSLocalizedString("Please set BrowserRouter manually in System Settings → Desktop & Dock → Default web browser.", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }

    // MARK: - Private

    private func showMissingBrowserAlert(browserId: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Browser Not Found", comment: "")
            alert.informativeText = String(format: NSLocalizedString("The browser \"%@\" is no longer installed. Please update your rules in Settings.", comment: ""), browserId)
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("Open Settings", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            if alert.runModal() == .alertFirstButtonReturn {
                NotificationCenter.default.post(name: .openPreferences, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let openPreferences = Notification.Name("BrowserRouterOpenPreferences")
}
