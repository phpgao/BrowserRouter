//
//  RuleStore.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import Foundation

/// Persists BrowserRule list (JSON file) and AppSettings (UserDefaults).
nonisolated final class RuleStore {

    private let rulesFileURL: URL
    private let defaults: UserDefaults
    private let settingsKey = "BrowserRouterAppSettings"
    private let statsKey = "BrowserRouterClickStats"

    /// Production init — uses Application Support directory.
    convenience init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrowserRouter", isDirectory: true)
        let fileURL = appSupport.appendingPathComponent("rules.json")
        self.init(rulesFileURL: fileURL)
    }

    /// Testable init — accepts custom file URL and UserDefaults suite.
    init(rulesFileURL: URL, defaults: UserDefaults = .standard) {
        self.rulesFileURL = rulesFileURL
        self.defaults = defaults
    }

    // MARK: - Rules

    func loadRules() throws -> [BrowserRule] {
        guard FileManager.default.fileExists(atPath: rulesFileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: rulesFileURL)
        return try JSONDecoder().decode([BrowserRule].self, from: data)
    }

    func save(rules: [BrowserRule]) throws {
        let dir = rulesFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(rules)
        try data.write(to: rulesFileURL, options: .atomic)
    }

    // MARK: - Settings

    func loadSettings() -> AppSettings {
        guard
            let data = defaults.data(forKey: settingsKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()  // default values
        }
        return settings
    }

    func save(settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }

    // MARK: - Click Stats

    /// Returns click counts keyed by browserId.
    func loadClickStats() -> [String: Int] {
        guard let data = defaults.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode([String: Int].self, from: data)
        else {
            return [:]
        }
        return stats
    }

    /// Increments the click count for the given browserId by 1.
    func recordClick(browserId: String) {
        var stats = loadClickStats()
        stats[browserId, default: 0] += 1
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: statsKey)
        }
    }

    /// Resets all click statistics.
    func resetClickStats() {
        defaults.removeObject(forKey: statsKey)
    }
}
