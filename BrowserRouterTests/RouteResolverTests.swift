//
//  RouteResolverTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/20.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class RouteResolverTests: XCTestCase {

    // MARK: - Helpers

    private func makeRule(
        pattern: String = "*.example.com",
        browserId: String = "com.google.Chrome",
        isEnabled: Bool = true
    ) -> BrowserRule {
        BrowserRule(pattern: pattern, browserId: browserId, isEnabled: isEnabled)
    }

    // MARK: - Force Show Picker

    func test_forceShowPicker_alwaysShowsPicker() {
        let rule = makeRule()
        let action = RouteResolver.resolve(
            matchedRule: rule,
            browserInstalled: true,
            defaultBehavior: .doNothing,
            forceShowPicker: true
        )
        XCTAssertEqual(action, .showPicker)
    }

    // MARK: - Rule Matched

    func test_ruleMatch_browserInstalled_opensBrowser() {
        let rule = makeRule(browserId: "com.google.Chrome")
        let action = RouteResolver.resolve(
            matchedRule: rule,
            browserInstalled: true,
            defaultBehavior: .showPicker,
            forceShowPicker: false
        )
        XCTAssertEqual(action, .openBrowser(browserId: "com.google.Chrome"))
    }

    func test_ruleMatch_browserMissing_showsWarning() {
        let rule = makeRule(browserId: "com.missing.Browser")
        let action = RouteResolver.resolve(
            matchedRule: rule,
            browserInstalled: false,
            defaultBehavior: .showPicker,
            forceShowPicker: false
        )
        XCTAssertEqual(action, .showWarning(matchedRule: rule))
    }

    // MARK: - No Match (Default Behavior)

    func test_noMatch_defaultShowPicker() {
        let action = RouteResolver.resolve(
            matchedRule: nil,
            browserInstalled: false,
            defaultBehavior: .showPicker,
            forceShowPicker: false
        )
        XCTAssertEqual(action, .showPicker)
    }

    func test_noMatch_defaultOpenInBrowser() {
        let action = RouteResolver.resolve(
            matchedRule: nil,
            browserInstalled: false,
            defaultBehavior: .openInBrowser("com.apple.Safari"),
            forceShowPicker: false
        )
        XCTAssertEqual(action, .openBrowser(browserId: "com.apple.Safari"))
    }

    func test_noMatch_defaultDoNothing() {
        let action = RouteResolver.resolve(
            matchedRule: nil,
            browserInstalled: false,
            defaultBehavior: .doNothing,
            forceShowPicker: false
        )
        XCTAssertEqual(action, .doNothing)
    }

    // MARK: - Edge Case

    func test_disabledRule_noMatch_fallsToDefault() {
        // URLRouter already skips disabled rules, so matchedRule arrives as nil.
        let action = RouteResolver.resolve(
            matchedRule: nil,
            browserInstalled: false,
            defaultBehavior: .openInBrowser("org.mozilla.firefox"),
            forceShowPicker: false
        )
        XCTAssertEqual(action, .openBrowser(browserId: "org.mozilla.firefox"))
    }
}
