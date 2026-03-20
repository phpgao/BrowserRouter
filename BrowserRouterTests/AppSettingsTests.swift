//
//  AppSettingsTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class AppSettingsTests: XCTestCase {

    func test_encode_decode_showPicker() throws {
        let settings = AppSettings(
            defaultBehavior: .showPicker,
            launchAtLogin: false,
            showQuickAddButton: false
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.defaultBehavior, .showPicker)
        XCTAssertFalse(decoded.launchAtLogin)
    }

    func test_encode_decode_openInBrowser() throws {
        let settings = AppSettings(
            defaultBehavior: .openInBrowser("com.google.Chrome"),
            launchAtLogin: true,
            showQuickAddButton: true
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.defaultBehavior, .openInBrowser("com.google.Chrome"))
        XCTAssertTrue(decoded.launchAtLogin)
        XCTAssertTrue(decoded.showQuickAddButton)
    }

    func test_encode_decode_doNothing() throws {
        let settings = AppSettings(
            defaultBehavior: .doNothing,
            launchAtLogin: false,
            showQuickAddButton: false
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.defaultBehavior, .doNothing)
    }

    func test_encode_decode_autoCheckUpdates() throws {
        let settings = AppSettings(autoCheckUpdates: false)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertFalse(decoded.autoCheckUpdates)
    }

    func test_autoCheckUpdates_defaultsToTrue() throws {
        let settings = AppSettings()
        XCTAssertTrue(settings.autoCheckUpdates)
    }

    func test_decode_oldData_autoCheckUpdates_defaultsTrue() throws {
        // Simulate old settings data without autoCheckUpdates field
        let json = """
        {"defaultBehavior":{"type":"showPicker"},"launchAtLogin":false,"showQuickAddButton":false,"browserOrder":[],"incognitoHoverEnabled":true,"incognitoHoverDelay":1.0,"language":""}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertTrue(decoded.autoCheckUpdates)
    }
}
