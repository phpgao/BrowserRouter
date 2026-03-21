//
//  AppStateStore.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import SwiftUI
import Combine
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BrowserRouter", category: "AppStateStore")

/// Observable bridge between SwiftUI and the persistence layer.
@MainActor
final class AppStateStore: ObservableObject {
    @Published var rules: [BrowserRule] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var installedBrowsers: [Browser] = []
    @Published var clickStats: [String: Int] = [:]

    /// UndoManager for rule operations — exposed so views/menus can connect.
    let undoManager = UndoManager()

    /// Browsers sorted and filtered by user preferences.
    /// Hidden browsers are excluded; order follows `settings.browserOrder`.
    var visibleBrowsers: [Browser] {
        let order = settings.browserOrder
        let hiddenIds = Set(order.filter { !$0.isVisible }.map { $0.browserId })
        let orderMap = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1.browserId, $0) })

        return installedBrowsers
            .filter { !hiddenIds.contains($0.id) }
            .sorted { a, b in
                let ia = orderMap[a.id] ?? Int.max
                let ib = orderMap[b.id] ?? Int.max
                return ia < ib
            }
    }

    private let ruleStore: RuleStore
    private let browserManager: BrowserManager

    /// Returns the installed browser matching the given bundle ID, or nil.
    func browser(for id: String) -> Browser? {
        installedBrowsers.first { $0.id == id }
    }

    init(ruleStore: RuleStore, browserManager: BrowserManager) {
        self.ruleStore = ruleStore
        self.browserManager = browserManager
        load()
    }

    func load() {
        do {
            rules = try ruleStore.loadRules()
        } catch {
            logger.error("Failed to load rules: \(error.localizedDescription)")
            rules = []
        }
        settings = ruleStore.loadSettings()
        installedBrowsers = browserManager.installedBrowsers
        clickStats = ruleStore.loadClickStats()
        syncBrowserOrder()
    }

    /// Ensures browserOrder stays in sync with installed browsers:
    /// - Removes entries for uninstalled browsers
    /// - Appends newly installed browsers at the end (visible by default)
    private func syncBrowserOrder() {
        let installedIds = Set(installedBrowsers.map { $0.id })
        var order = settings.browserOrder.filter { installedIds.contains($0.browserId) }
        let existingIds = Set(order.map { $0.browserId })
        for browser in installedBrowsers where !existingIds.contains(browser.id) {
            order.append(BrowserOrderItem(browserId: browser.id))
        }
        if order != settings.browserOrder {
            settings.browserOrder = order
            saveSettings()
        }
    }

    func saveRules() {
        do {
            try ruleStore.save(rules: rules)
        } catch {
            logger.error("Failed to save rules: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    func saveSettings() {
        ruleStore.save(settings: settings)
        NotificationCenter.default.post(name: .settingsDidChange, object: nil)
    }

    func addRules(patterns: [String], browserId: String) {
        let existing = Set(rules.map { $0.pattern })
        let newRules = patterns
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !existing.contains($0) }
            .map { BrowserRule(pattern: $0, browserId: browserId) }
        guard !newRules.isEmpty else { return }
        let oldRules = rules
        rules.append(contentsOf: newRules)
        saveRules()
        registerUndo(oldRules: oldRules, actionName: NSLocalizedString("Add Rules", comment: "Undo action"))
    }

    func deleteRule(at offsets: IndexSet) {
        let oldRules = rules
        rules.remove(atOffsets: offsets)
        saveRules()
        registerUndo(oldRules: oldRules, actionName: NSLocalizedString("Delete Rule", comment: "Undo action"))
    }

    func moveRule(from source: IndexSet, to destination: Int) {
        let oldRules = rules
        rules.move(fromOffsets: source, toOffset: destination)
        saveRules()
        registerUndo(oldRules: oldRules, actionName: NSLocalizedString("Move Rule", comment: "Undo action"))
    }

    /// Registers an undo action that restores rules to the given snapshot.
    private func registerUndo(oldRules: [BrowserRule], actionName: String) {
        let currentRules = rules
        undoManager.registerUndo(withTarget: self) { store in
            MainActor.assumeIsolated {
                let redoSnapshot = store.rules
                store.rules = oldRules
                store.saveRules()
                store.registerUndo(oldRules: redoSnapshot, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    // MARK: - Export / Import

    /// Lightweight export representation — omits the internal UUID.
    private struct ExportRule: Codable {
        let pattern: String
        let browserId: String
        let isEnabled: Bool
    }

    /// Export current rules to a JSON file (without internal id).
    func exportRules(to url: URL) throws {
        let exportable = rules.map { ExportRule(pattern: $0.pattern, browserId: $0.browserId, isEnabled: $0.isEnabled) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(exportable)
        try data.write(to: url, options: .atomic)
    }

    enum ImportMode { case merge, replace }

    struct ImportResult {
        let importedCount: Int
        let skippedCount: Int
    }

    /// Import rules from a JSON file.
    /// - `mode`: merge (keep existing, append new deduplicated) or replace (clear all, import).
    func importRules(from url: URL, mode: ImportMode) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let raw = try JSONDecoder().decode([ExportRule].self, from: data)
        let incoming = raw.map { BrowserRule(pattern: $0.pattern, browserId: $0.browserId, isEnabled: $0.isEnabled) }

        let oldRules = rules
        var importedCount = 0
        var skippedCount = 0

        switch mode {
        case .replace:
            importedCount = incoming.count
            rules = incoming
        case .merge:
            let existingPatterns = Set(rules.map { $0.pattern })
            for rule in incoming {
                if existingPatterns.contains(rule.pattern) {
                    skippedCount += 1
                } else {
                    rules.append(rule)
                    importedCount += 1
                }
            }
        }

        saveRules()
        registerUndo(oldRules: oldRules, actionName: NSLocalizedString("Import Rules", comment: "Undo action"))
        return ImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount
        )
    }

    // MARK: - Click Stats

    func recordClick(browserId: String) {
        ruleStore.recordClick(browserId: browserId)
        clickStats[browserId, default: 0] += 1  // update in memory directly
    }

    func resetClickStats() {
        ruleStore.resetClickStats()
        clickStats = [:]
    }

    // MARK: - Browser Order

    func moveBrowser(from source: IndexSet, to destination: Int) {
        settings.browserOrder.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }

    func toggleBrowserVisibility(browserId: String) {
        guard let idx = settings.browserOrder.firstIndex(where: { $0.browserId == browserId }) else { return }
        settings.browserOrder[idx].isVisible.toggle()
        saveSettings()
    }
}
