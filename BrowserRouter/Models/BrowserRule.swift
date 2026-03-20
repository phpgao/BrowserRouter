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

struct AppSettings: Equatable {
    var defaultBehavior: DefaultBehavior
    var launchAtLogin: Bool
    var showQuickAddButton: Bool
    var browserOrder: [BrowserOrderItem]
    var incognitoHoverEnabled: Bool
    var incognitoHoverDelay: Double  // seconds
    var language: String  // "" = system, or "en", "zh-Hans", "zh-Hant", "ja"
    var autoCheckUpdates: Bool  // whether Sparkle auto-checks for updates

    init(
        defaultBehavior: DefaultBehavior = .showPicker,
        launchAtLogin: Bool = false,
        showQuickAddButton: Bool = false,
        browserOrder: [BrowserOrderItem] = [],
        incognitoHoverEnabled: Bool = true,
        incognitoHoverDelay: Double = 1.0,
        language: String = "",
        autoCheckUpdates: Bool = true
    ) {
        self.defaultBehavior = defaultBehavior
        self.launchAtLogin = launchAtLogin
        self.showQuickAddButton = showQuickAddButton
        self.browserOrder = browserOrder
        self.incognitoHoverEnabled = incognitoHoverEnabled
        self.incognitoHoverDelay = incognitoHoverDelay
        self.language = language
        self.autoCheckUpdates = autoCheckUpdates
    }

    enum DefaultBehavior: Equatable {
        case showPicker
        case openInBrowser(String)  // browserId
        case doNothing
    }
}

// MARK: - Custom Codable for AppSettings
// Explicit Codable to handle backward compatibility when new fields are added.

extension AppSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case defaultBehavior, launchAtLogin, showQuickAddButton, browserOrder
        case incognitoHoverEnabled, incognitoHoverDelay, language, autoCheckUpdates
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultBehavior, forKey: .defaultBehavior)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(showQuickAddButton, forKey: .showQuickAddButton)
        try container.encode(browserOrder, forKey: .browserOrder)
        try container.encode(incognitoHoverEnabled, forKey: .incognitoHoverEnabled)
        try container.encode(incognitoHoverDelay, forKey: .incognitoHoverDelay)
        try container.encode(language, forKey: .language)
        try container.encode(autoCheckUpdates, forKey: .autoCheckUpdates)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultBehavior = try container.decode(DefaultBehavior.self, forKey: .defaultBehavior)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        showQuickAddButton = try container.decode(Bool.self, forKey: .showQuickAddButton)
        browserOrder = try container.decodeIfPresent([BrowserOrderItem].self, forKey: .browserOrder) ?? []
        incognitoHoverEnabled = try container.decodeIfPresent(Bool.self, forKey: .incognitoHoverEnabled) ?? true
        incognitoHoverDelay = try container.decodeIfPresent(Double.self, forKey: .incognitoHoverDelay) ?? 1.0
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? ""
        autoCheckUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoCheckUpdates) ?? true
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
