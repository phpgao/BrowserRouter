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
}
