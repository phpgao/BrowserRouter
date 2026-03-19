//
//  BrowserRule.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/19.
//

import Foundation

struct BrowserRule: Identifiable, Codable, Equatable {
    let id: UUID
    var pattern: String
    var browserId: String
    var isEnabled: Bool

    init(id: UUID = UUID(), pattern: String, browserId: String, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.browserId = browserId
        self.isEnabled = isEnabled
    }
}

struct AppSettings: Codable, Equatable {
    var defaultBehavior: DefaultBehavior
    var launchAtLogin: Bool
    var showQuickAddButton: Bool
    var browserOrder: [BrowserOrderItem]
    var incognitoHoverEnabled: Bool
    var incognitoHoverDelay: Double  // seconds
    var language: String  // "" = system, or "en", "zh-Hans", "zh-Hant", "ja"

    init(
        defaultBehavior: DefaultBehavior = .showPicker,
        launchAtLogin: Bool = false,
        showQuickAddButton: Bool = false,
        browserOrder: [BrowserOrderItem] = [],
        incognitoHoverEnabled: Bool = true,
        incognitoHoverDelay: Double = 1.0,
        language: String = ""
    ) {
        self.defaultBehavior = defaultBehavior
        self.launchAtLogin = launchAtLogin
        self.showQuickAddButton = showQuickAddButton
        self.browserOrder = browserOrder
        self.incognitoHoverEnabled = incognitoHoverEnabled
        self.incognitoHoverDelay = incognitoHoverDelay
        self.language = language
    }

    enum DefaultBehavior: Equatable {
        case showPicker
        case openInBrowser(String)  // browserId
        case doNothing
    }
}

// MARK: - Custom Codable for DefaultBehavior
// Swift cannot auto-synthesize Codable for enums with associated values.

extension AppSettings.DefaultBehavior: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, browserId
    }
    private enum BehaviorType: String, Codable {
        case showPicker, openInBrowser, doNothing
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .showPicker:
            try container.encode(BehaviorType.showPicker, forKey: .type)
        case .openInBrowser(let id):
            try container.encode(BehaviorType.openInBrowser, forKey: .type)
            try container.encode(id, forKey: .browserId)
        case .doNothing:
            try container.encode(BehaviorType.doNothing, forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BehaviorType.self, forKey: .type)
        switch type {
        case .showPicker:
            self = .showPicker
        case .openInBrowser:
            let id = try container.decode(String.self, forKey: .browserId)
            self = .openInBrowser(id)
        case .doNothing:
            self = .doNothing
        }
    }
}

// MARK: - Browser Order

/// Persisted browser visibility and ordering preference.
struct BrowserOrderItem: Codable, Equatable, Identifiable {
    var id: String { browserId }
    let browserId: String
    var isVisible: Bool

    init(browserId: String, isVisible: Bool = true) {
        self.browserId = browserId
        self.isVisible = isVisible
    }
}
