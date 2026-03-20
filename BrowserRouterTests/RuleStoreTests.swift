//
//  RuleStoreTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class RuleStoreTests: XCTestCase {

    var store: RuleStore!
    var tempURL: URL!
    private var defaultsSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-rules-\(UUID().uuidString).json")
        defaultsSuiteName = "com.jimmy.BrowserRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        store = RuleStore(rulesFileURL: tempURL, defaults: defaults)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempURL)
        if let name = defaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        try await super.tearDown()
    }

    func test_saveAndLoad_rulesRoundTrip() throws {
        let rules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome"),
            BrowserRule(pattern: "work.app/**", browserId: "com.microsoft.edgemac"),
        ]
        try store.save(rules: rules)
        let loaded = try store.loadRules()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].pattern, "*.github.com")
        XCTAssertEqual(loaded[1].browserId, "com.microsoft.edgemac")
    }

    func test_load_returnsEmptyArrayWhenFileAbsent() throws {
        let loaded = try store.loadRules()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_save_overwritesPreviousRules() throws {
        try store.save(rules: [BrowserRule(pattern: "*.a.com", browserId: "com.apple.Safari")])
        try store.save(rules: [BrowserRule(pattern: "*.b.com", browserId: "com.google.Chrome")])
        let loaded = try store.loadRules()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].pattern, "*.b.com")
    }

    func test_settings_defaultValues() {
        let settings = store.loadSettings()
        XCTAssertEqual(settings.defaultBehavior, .showPicker)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertFalse(settings.showQuickAddButton)
    }

    func test_settings_saveAndLoad() {
        let settings = AppSettings(
            defaultBehavior: .openInBrowser("com.google.Chrome"),
            launchAtLogin: true,
            showQuickAddButton: true
        )
        store.save(settings: settings)
        let loaded = store.loadSettings()
        XCTAssertEqual(loaded.defaultBehavior, .openInBrowser("com.google.Chrome"))
        XCTAssertTrue(loaded.launchAtLogin)
    }

    // MARK: - Click Stats

    func test_clickStats_initiallyEmpty() {
        let stats = store.loadClickStats()
        XCTAssertTrue(stats.isEmpty)
    }

    func test_recordClick_incrementsCount() {
        store.recordClick(browserId: "com.apple.Safari")
        store.recordClick(browserId: "com.apple.Safari")
        store.recordClick(browserId: "com.google.Chrome")
        let stats = store.loadClickStats()
        XCTAssertEqual(stats["com.apple.Safari"], 2)
        XCTAssertEqual(stats["com.google.Chrome"], 1)
    }

    func test_resetClickStats_clearsAll() {
        store.recordClick(browserId: "com.apple.Safari")
        store.resetClickStats()
        let stats = store.loadClickStats()
        XCTAssertTrue(stats.isEmpty)
    }

    // MARK: - Rules with isEnabled

    func test_saveAndLoad_preservesIsEnabled() throws {
        let rules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome", isEnabled: false),
            BrowserRule(pattern: "*.example.com", browserId: "com.apple.Safari", isEnabled: true),
        ]
        try store.save(rules: rules)
        let loaded = try store.loadRules()
        XCTAssertFalse(loaded[0].isEnabled)
        XCTAssertTrue(loaded[1].isEnabled)
    }

    // MARK: - Settings Edge Cases

    func test_settings_doNothing_roundTrip() {
        let settings = AppSettings(defaultBehavior: .doNothing)
        store.save(settings: settings)
        let loaded = store.loadSettings()
        XCTAssertEqual(loaded.defaultBehavior, .doNothing)
    }

    func test_settings_allFields_roundTrip() {
        let settings = AppSettings(
            defaultBehavior: .showPicker,
            launchAtLogin: true,
            showQuickAddButton: true,
            browserOrder: [BrowserOrderItem(browserId: "com.apple.Safari", isVisible: false)],
            incognitoHoverEnabled: false,
            incognitoHoverDelay: 2.5,
            language: "zh-Hans"
        )
        store.save(settings: settings)
        let loaded = store.loadSettings()
        XCTAssertEqual(loaded.defaultBehavior, .showPicker)
        XCTAssertTrue(loaded.launchAtLogin)
        XCTAssertTrue(loaded.showQuickAddButton)
        XCTAssertEqual(loaded.browserOrder.count, 1)
        XCTAssertFalse(loaded.browserOrder[0].isVisible)
        XCTAssertFalse(loaded.incognitoHoverEnabled)
        XCTAssertEqual(loaded.incognitoHoverDelay, 2.5)
        XCTAssertEqual(loaded.language, "zh-Hans")
    }
}
