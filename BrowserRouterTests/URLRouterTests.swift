//
//  URLRouterTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class URLRouterTests: XCTestCase {

    // MARK: - URL Normalization

    func test_normalize_stripsScheme() {
        XCTAssertEqual(URLRouter.normalize(URL(string: "https://github.com/repo")!), "github.com/repo")
    }

    func test_normalize_stripsQuery() {
        XCTAssertEqual(URLRouter.normalize(URL(string: "https://github.com/repo?tab=issues")!), "github.com/repo")
    }

    func test_normalize_stripsFragment() {
        XCTAssertEqual(URLRouter.normalize(URL(string: "https://github.com/repo#comment")!), "github.com/repo")
    }

    func test_normalize_lowercasesHost() {
        XCTAssertEqual(URLRouter.normalize(URL(string: "https://GitHub.COM/Repo")!), "github.com/Repo")
    }

    func test_normalize_trailingSlashBareHost() {
        XCTAssertEqual(URLRouter.normalize(URL(string: "https://github.com/")!), "github.com")
    }

    // MARK: - Pattern Compilation

    func test_compile_singleWildcard_matchesSingleLabel() {
        let regex = try! URLRouter.compilePattern("*.github.com")
        XCTAssertTrue(regex.matches("app.github.com"))
        XCTAssertFalse(regex.matches("github.com"))
        XCTAssertFalse(regex.matches("a.b.github.com"))
    }

    func test_compile_doubleWildcard_matchesMultipleLevels() {
        let regex = try! URLRouter.compilePattern("**.github.com")
        XCTAssertTrue(regex.matches("app.github.com"))
        XCTAssertTrue(regex.matches("a.b.github.com"))
        XCTAssertFalse(regex.matches("github.com"))
    }

    func test_compile_pathPattern_matchesFullPath() {
        let regex = try! URLRouter.compilePattern("github.com/**")
        XCTAssertTrue(regex.matches("github.com/work/repo"))
        XCTAssertFalse(regex.matches("github.com"))
        XCTAssertFalse(regex.matches("github.com/"))
    }

    func test_compile_singleSegmentPath() {
        let regex = try! URLRouter.compilePattern("work.app/*")
        XCTAssertTrue(regex.matches("work.app/dashboard"))
        XCTAssertFalse(regex.matches("work.app/a/b"))
    }

    func test_compile_exactDomain() {
        let regex = try! URLRouter.compilePattern("github.com")
        XCTAssertTrue(regex.matches("github.com"))
        XCTAssertFalse(regex.matches("app.github.com"))
    }

    // MARK: - Route Matching

    func test_match_returnsFirstEnabledRule() {
        let rules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome"),
            BrowserRule(pattern: "**.github.com", browserId: "com.apple.Safari"),
        ]
        let router = try! URLRouter(rules: rules)
        let result = router.match(URL(string: "https://app.github.com/repo")!)
        XCTAssertEqual(result?.browserId, "com.google.Chrome")
    }

    func test_match_skipsDisabledRules() {
        let rules = [
            BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome", isEnabled: false),
            BrowserRule(pattern: "**.github.com", browserId: "com.apple.Safari"),
        ]
        let router = try! URLRouter(rules: rules)
        let result = router.match(URL(string: "https://app.github.com/repo")!)
        XCTAssertEqual(result?.browserId, "com.apple.Safari")
    }

    func test_match_returnsNilWhenNoMatch() {
        let rules = [BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome")]
        let router = try! URLRouter(rules: rules)
        let result = router.match(URL(string: "https://google.com")!)
        XCTAssertNil(result)
    }

    func test_match_hostOnlyPatternMatchesURLWithPath() {
        // Host-only pattern must match even when URL has a path
        let rules = [BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome")]
        let router = try! URLRouter(rules: rules)
        let result = router.match(URL(string: "https://app.github.com/some/deep/path")!)
        XCTAssertEqual(result?.browserId, "com.google.Chrome")
    }
}

// Helper
private extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return firstMatch(in: string, range: range) != nil
    }
}
