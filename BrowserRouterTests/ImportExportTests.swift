//
//  ImportExportTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/20.
//

import XCTest
@testable import BrowserRouter

final class ImportExportTests: XCTestCase {

    var store: RuleStore!
    var tempURL: URL!
    var exportURL: URL!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-rules-\(UUID().uuidString).json")
        exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-rules-\(UUID().uuidString).json")
        defaultsSuiteName = "com.jimmy.BrowserRouterTests.IE.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        store = RuleStore(rulesFileURL: tempURL, defaults: defaults)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: exportURL)
        if let name = defaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        super.tearDown()
    }

    // MARK: - Export / Import Round-Trip

    func test_exportImportRoundTrip() throws {
        let rules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome"),
            BrowserRule(pattern: "*.example.com", browserId: "com.apple.Safari"),
        ]
        try store.save(rules: rules)

        // Export
        let loaded = try store.loadRules()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(loaded)
        try data.write(to: exportURL, options: .atomic)

        // Verify exported JSON is valid
        let importedData = try Data(contentsOf: exportURL)
        let imported = try JSONDecoder().decode([BrowserRule].self, from: importedData)
        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(imported[0].pattern, "*.github.com")
        XCTAssertEqual(imported[1].pattern, "*.example.com")
    }

    // MARK: - Import with Merge (dedup)

    func test_importMerge_deduplicatesByPattern() throws {
        // Setup: existing rules
        let existing = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome"),
        ]
        try store.save(rules: existing)

        // Create import file with one duplicate and one new
        let importRules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.apple.Safari"),  // duplicate pattern
            BrowserRule(pattern: "*.example.com", browserId: "com.apple.Safari"),  // new
        ]
        let data = try JSONEncoder().encode(importRules)
        try data.write(to: exportURL, options: .atomic)

        // Load existing, do merge
        var currentRules = try store.loadRules()
        let incoming = try JSONDecoder().decode([BrowserRule].self, from: Data(contentsOf: exportURL))
        let existingPatterns = Set(currentRules.map { $0.pattern })
        var importedCount = 0
        var skippedCount = 0
        for rule in incoming {
            if existingPatterns.contains(rule.pattern) {
                skippedCount += 1
            } else {
                currentRules.append(BrowserRule(pattern: rule.pattern, browserId: rule.browserId, isEnabled: rule.isEnabled))
                importedCount += 1
            }
        }
        try store.save(rules: currentRules)

        XCTAssertEqual(importedCount, 1)
        XCTAssertEqual(skippedCount, 1)

        let finalRules = try store.loadRules()
        XCTAssertEqual(finalRules.count, 2)
        XCTAssertEqual(finalRules[0].pattern, "*.github.com")
        XCTAssertEqual(finalRules[0].browserId, "com.google.Chrome")  // kept original
        XCTAssertEqual(finalRules[1].pattern, "*.example.com")
    }

    // MARK: - Import with Replace

    func test_importReplace_clearsExisting() throws {
        // Setup: existing rules
        let existing = [
            BrowserRule(pattern: "*.old.com", browserId: "com.google.Chrome"),
            BrowserRule(pattern: "*.legacy.com", browserId: "com.google.Chrome"),
        ]
        try store.save(rules: existing)

        // Create import file
        let importRules = [
            BrowserRule(pattern: "*.new.com", browserId: "com.apple.Safari"),
        ]
        let data = try JSONEncoder().encode(importRules)
        try data.write(to: exportURL, options: .atomic)

        // Replace
        let incoming = try JSONDecoder().decode([BrowserRule].self, from: Data(contentsOf: exportURL))
        let newRules = incoming.map {
            BrowserRule(pattern: $0.pattern, browserId: $0.browserId, isEnabled: $0.isEnabled)
        }
        try store.save(rules: newRules)

        let finalRules = try store.loadRules()
        XCTAssertEqual(finalRules.count, 1)
        XCTAssertEqual(finalRules[0].pattern, "*.new.com")
    }
}
