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

    // MARK: - Query Pattern Matching

    func test_match_queryPattern_matchesURLWithQuery() {
        let rules = [BrowserRule(pattern: "example.com/search?q=**", browserId: "com.google.Chrome")]
        let router = try! URLRouter(rules: rules)
        let result = router.match(URL(string: "https://example.com/search?q=hello")!)
        XCTAssertEqual(result?.browserId, "com.google.Chrome")
    }

    func test_match_queryPattern_doesNotMatchWithoutQuery() {
        let rules = [BrowserRule(pattern: "example.com/search?q=**", browserId: "com.google.Chrome")]
        let router = try! URLRouter(rules: rules)
        let result = router.match(URL(string: "https://example.com/search")!)
        XCTAssertNil(result)
    }

    // MARK: - Update Rules

    func test_update_replacesRules() {
        let rules1 = [BrowserRule(pattern: "*.github.com", browserId: "com.google.Chrome")]
        let router = try! URLRouter(rules: rules1)

        let rules2 = [BrowserRule(pattern: "*.example.com", browserId: "com.apple.Safari")]
        try! router.update(rules: rules2)

        XCTAssertNil(router.match(URL(string: "https://app.github.com")!))
        XCTAssertEqual(router.match(URL(string: "https://app.example.com")!)?.browserId, "com.apple.Safari")
    }

    // MARK: - Static matches() Helper

    func test_staticMatches_singlePattern() {
        XCTAssertTrue(URLRouter.matches(pattern: "*.github.com", url: URL(string: "https://app.github.com")!))
        XCTAssertFalse(URLRouter.matches(pattern: "*.github.com", url: URL(string: "https://google.com")!))
    }

    func test_staticMatches_invalidPatternReturnsFalse() {
        XCTAssertFalse(URLRouter.matches(pattern: "[invalid", url: URL(string: "https://example.com")!))
    }

    // MARK: - Normalize with keepQuery

    func test_normalize_keepQuery_preservesQueryString() {
        let url = URL(string: "https://example.com/path?key=value")!
        let result = URLRouter.normalize(url, keepQuery: true)
        XCTAssertTrue(result.contains("key=value"))
    }

    func test_normalize_keepQuery_false_stripsQuery() {
        let url = URL(string: "https://example.com/path?key=value")!
        let result = URLRouter.normalize(url, keepQuery: false)
        XCTAssertFalse(result.contains("key=value"))
    }

    // MARK: - Pattern Compilation Edge Cases

    func test_compile_escapesRegexMetacharacters() {
        // Dot should be literal, not regex "any character"
        let regex = try! URLRouter.compilePattern("example.com")
        XCTAssertTrue(regex.matches("example.com"))
        // Dot is escaped, so "exampleXcom" should NOT match
        XCTAssertFalse(regex.matches("exampleXcom"))
    }

    func test_compile_questionMarkInPattern() {
        let regex = try! URLRouter.compilePattern("example.com/page?id=*")
        XCTAssertTrue(regex.matches("example.com/page?id=123"))
        XCTAssertFalse(regex.matches("example.com/page"))
    }
}

// Helper
private extension NSRegularExpression {
    func matches(_ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return firstMatch(in: string, range: range) != nil
    }
}
