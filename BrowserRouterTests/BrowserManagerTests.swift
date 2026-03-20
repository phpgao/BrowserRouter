//
//  BrowserManagerTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class BrowserManagerTests: XCTestCase {

    func test_detectedBrowsers_containsSafari() async {
        // Safari is always present on macOS
        let manager = BrowserManager()
        let browsers = manager.installedBrowsers
        XCTAssertTrue(browsers.contains { $0.id == "com.apple.Safari" },
                      "Safari should always be detected on macOS")
    }

    func test_detectedBrowsers_haveNames() async {
        let manager = BrowserManager()
        for browser in manager.installedBrowsers {
            XCTAssertFalse(browser.name.isEmpty, "Browser \(browser.id) has empty name")
        }
    }

    func test_browser_forId_returnsCorrectBrowser() async {
        let manager = BrowserManager()
        let safari = manager.browser(forId: "com.apple.Safari")
        XCTAssertNotNil(safari)
        XCTAssertEqual(safari?.id, "com.apple.Safari")
    }

    func test_browser_forId_unknownIdReturnsNil() async {
        let manager = BrowserManager()
        let result = manager.browser(forId: "com.fake.NotABrowser")
        XCTAssertNil(result)
    }

    // MARK: - Refresh

    func test_refresh_repopulatesBrowserList() async {
        let manager = BrowserManager()
        let beforeCount = manager.installedBrowsers.count
        manager.refresh()
        XCTAssertEqual(manager.installedBrowsers.count, beforeCount)
    }

    // MARK: - Browser Properties

    func test_safari_hasVersion() async {
        let manager = BrowserManager()
        let safari = manager.browser(forId: "com.apple.Safari")
        XCTAssertNotNil(safari?.version, "Safari should have a version string")
    }

    func test_safari_hasIcon() async {
        let manager = BrowserManager()
        let safari = manager.browser(forId: "com.apple.Safari")
        XCTAssertNotNil(safari?.icon, "Safari should have an icon")
    }

    func test_detectedBrowsers_haveUniqueIds() async {
        let manager = BrowserManager()
        let ids = manager.installedBrowsers.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count, "Browser IDs should be unique")
    }

}
