//
//  AppStateStoreTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/20.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class AppStateStoreTests: XCTestCase {

    var ruleStore: RuleStore!
    var browserManager: BrowserManager!
    var store: AppStateStore!
    private var tempURL: URL!
    private var exportURL: URL!
    private var defaultsSuiteName: String!

    override func setUp() async throws {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-appstate-\(UUID().uuidString).json")
        exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-export-\(UUID().uuidString).json")
        defaultsSuiteName = "com.jimmy.BrowserRouterTests.AS.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        ruleStore = RuleStore(rulesFileURL: tempURL, defaults: defaults)
        browserManager = BrowserManager()
        store = AppStateStore(ruleStore: ruleStore, browserManager: browserManager)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: exportURL)
        if let name = defaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
    }

    // MARK: - Add Rules

    func test_addRules_appendsNewRules() {
        store.addRules(patterns: ["*.github.com", "*.example.com"], browserId: "com.apple.Safari")
        XCTAssertEqual(store.rules.count, 2)
        XCTAssertEqual(store.rules[0].pattern, "*.github.com")
        XCTAssertEqual(store.rules[1].pattern, "*.example.com")
    }

    func test_addRules_deduplicatesExisting() {
        store.addRules(patterns: ["*.github.com"], browserId: "com.apple.Safari")
        store.addRules(patterns: ["*.github.com", "*.new.com"], browserId: "com.google.Chrome")
        XCTAssertEqual(store.rules.count, 2)
        XCTAssertEqual(store.rules[0].browserId, "com.apple.Safari")  // original kept
        XCTAssertEqual(store.rules[1].pattern, "*.new.com")
    }

    func test_addRules_ignoresEmptyAndWhitespace() {
        store.addRules(patterns: ["", "  ", "*.valid.com"], browserId: "com.apple.Safari")
        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules[0].pattern, "*.valid.com")
    }

    func test_addRules_persistsToStore() throws {
        store.addRules(patterns: ["*.github.com"], browserId: "com.apple.Safari")
        let loaded = try ruleStore.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].pattern, "*.github.com")
    }

    // MARK: - Delete Rules

    func test_deleteRule_removesAtIndex() {
        store.addRules(patterns: ["*.a.com", "*.b.com", "*.c.com"], browserId: "com.apple.Safari")
        store.deleteRule(at: IndexSet(integer: 1))
        XCTAssertEqual(store.rules.count, 2)
        XCTAssertEqual(store.rules[0].pattern, "*.a.com")
        XCTAssertEqual(store.rules[1].pattern, "*.c.com")
    }

    // MARK: - Move Rules

    func test_moveRule_reorders() {
        store.addRules(patterns: ["*.a.com", "*.b.com", "*.c.com"], browserId: "com.apple.Safari")
        store.moveRule(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(store.rules[0].pattern, "*.c.com")
        XCTAssertEqual(store.rules[1].pattern, "*.a.com")
        XCTAssertEqual(store.rules[2].pattern, "*.b.com")
    }

    // MARK: - Visible Browsers

    func test_visibleBrowsers_excludesHidden() {
        // Safari is always installed
        let safariId = "com.apple.Safari"
        guard store.installedBrowsers.contains(where: { $0.id == safariId }) else { return }

        // Hide Safari
        if let idx = store.settings.browserOrder.firstIndex(where: { $0.browserId == safariId }) {
            store.settings.browserOrder[idx].isVisible = false
        }
        let visible = store.visibleBrowsers
        XCTAssertFalse(visible.contains { $0.id == safariId })
    }

    func test_visibleBrowsers_respectsOrder() {
        let browsers = store.installedBrowsers
        guard browsers.count >= 2 else { return }

        // Reverse the order
        store.settings.browserOrder = browsers.reversed().map {
            BrowserOrderItem(browserId: $0.id)
        }
        let visible = store.visibleBrowsers
        XCTAssertEqual(visible.first?.id, browsers.last?.id)
    }

    // MARK: - Export / Import

    func test_exportRules_writesJSON() throws {
        store.addRules(patterns: ["*.github.com"], browserId: "com.apple.Safari")
        try store.exportRules(to: exportURL)

        let data = try Data(contentsOf: exportURL)
        let json = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        XCTAssertEqual(json.count, 1)
        XCTAssertEqual(json[0]["pattern"] as? String, "*.github.com")
        XCTAssertEqual(json[0]["browserId"] as? String, "com.apple.Safari")
        XCTAssertEqual(json[0]["isEnabled"] as? Bool, true)
    }

    func test_importRules_replace() throws {
        store.addRules(patterns: ["*.old.com"], browserId: "com.apple.Safari")

        let importRules = [BrowserRule(pattern: "*.new.com", browserId: "com.google.Chrome")]
        let data = try JSONEncoder().encode(importRules)
        try data.write(to: exportURL, options: .atomic)

        let result = try store.importRules(from: exportURL, mode: .replace)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules[0].pattern, "*.new.com")
    }

    func test_importRules_merge_skipsDuplicates() throws {
        store.addRules(patterns: ["*.github.com"], browserId: "com.apple.Safari")

        let importRules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome"),  // dup
            BrowserRule(pattern: "*.new.com", browserId: "com.google.Chrome"),
        ]
        let data = try JSONEncoder().encode(importRules)
        try data.write(to: exportURL, options: .atomic)

        let result = try store.importRules(from: exportURL, mode: .merge)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(store.rules.count, 2)
        XCTAssertEqual(store.rules[0].browserId, "com.apple.Safari")  // original kept
    }

    func test_importRules_preservesDisabledState() throws {
        let importRules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.nonexistent.Browser", isEnabled: false),
        ]
        let data = try JSONEncoder().encode(importRules)
        try data.write(to: exportURL, options: .atomic)

        let result = try store.importRules(from: exportURL, mode: .replace)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertFalse(store.rules[0].isEnabled)
    }

    // MARK: - Click Stats

    func test_recordClick_incrementsCount() {
        store.recordClick(browserId: "com.apple.Safari")
        store.recordClick(browserId: "com.apple.Safari")
        store.recordClick(browserId: "com.google.Chrome")
        XCTAssertEqual(store.clickStats["com.apple.Safari"], 2)
        XCTAssertEqual(store.clickStats["com.google.Chrome"], 1)
    }

    func test_resetClickStats_clearsAll() {
        store.recordClick(browserId: "com.apple.Safari")
        store.resetClickStats()
        XCTAssertTrue(store.clickStats.isEmpty)
    }

    // MARK: - Browser Order

    func test_toggleBrowserVisibility() {
        guard let first = store.settings.browserOrder.first else { return }
        let wasVisible = first.isVisible
        store.toggleBrowserVisibility(browserId: first.browserId)
        XCTAssertEqual(store.settings.browserOrder.first?.isVisible, !wasVisible)
    }

    func test_moveBrowser_reorders() {
        guard store.settings.browserOrder.count >= 2 else { return }
        let originalFirst = store.settings.browserOrder[0].browserId
        store.moveBrowser(from: IndexSet(integer: 0), to: 2)
        XCTAssertEqual(store.settings.browserOrder[1].browserId, originalFirst)
    }

    // MARK: - Browser Lookup

    func test_browserForId_returnsMatch() {
        let safari = store.browser(for: "com.apple.Safari")
        XCTAssertNotNil(safari)
        XCTAssertEqual(safari?.name, "Safari")
    }

    func test_browserForId_returnsNilForUnknown() {
        XCTAssertNil(store.browser(for: "com.fake.Browser"))
    }
}
