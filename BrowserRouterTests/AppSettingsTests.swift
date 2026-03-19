//
//  AppSettingsTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

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
}
