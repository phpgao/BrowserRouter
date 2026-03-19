//
//  RuleStoreTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

final class RuleStoreTests: XCTestCase {

    var store: RuleStore!
    var tempURL: URL!
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-rules-\(UUID().uuidString).json")
        testDefaults = UserDefaults(suiteName: "com.jimmy.BrowserRouterTests.\(UUID().uuidString)")!
        store = RuleStore(rulesFileURL: tempURL, defaults: testDefaults)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        testDefaults.removePersistentDomain(forName: testDefaults.description)
        super.tearDown()
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
}
