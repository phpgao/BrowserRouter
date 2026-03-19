//
//  PatternValidationTests.swift
//  BrowserRouterTests
//
//  Created by jimmy on 2026/3/19.
//

import XCTest
@testable import BrowserRouter

@MainActor
final class PatternValidationTests: XCTestCase {

    func test_valid_exactDomain() {
        XCTAssertNil(URLRouter.validate("github.com"))
    }

    func test_valid_singleWildcard() {
        XCTAssertNil(URLRouter.validate("*.github.com"))
    }

    func test_valid_doubleWildcard() {
        XCTAssertNil(URLRouter.validate("**.github.com"))
    }

    func test_valid_pathPattern() {
        XCTAssertNil(URLRouter.validate("github.com/**"))
    }

    func test_invalid_empty() {
        XCTAssertNotNil(URLRouter.validate(""))
    }

    func test_invalid_whitespaceOnly() {
        XCTAssertNotNil(URLRouter.validate("   "))
    }

    func test_invalid_containsSpace() {
        XCTAssertNotNil(URLRouter.validate("github .com"))
    }

    func test_invalid_containsBracket() {
        XCTAssertNotNil(URLRouter.validate("[github.com]"))
    }
}
