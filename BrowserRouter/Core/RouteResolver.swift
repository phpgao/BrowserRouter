//
//  RouteResolver.swift
//  BrowserRouter
//
//  Created by jimmy on 2026/3/20.
//

import Foundation

/// The resolved action for a URL routing decision — pure value, no side effects.
enum RouteAction: Equatable {
    case openBrowser(browserId: String)
    case showPicker
    case showWarning(matchedRule: BrowserRule)  // rule matched but browser missing
    case showDefaultBrowserWarning(browserId: String)  // fallback browser missing
    case doNothing
}

/// Pure-function route resolver. Extracted from AppDelegate.route() for testability.
struct RouteResolver {

    /// Determine which action to take for a URL based on rule match state and settings.
    ///
    /// Decision tree:
    /// 1. `forceShowPicker` → `.showPicker`
    /// 2. Rule matched & browser installed → `.openBrowser(rule.browserId)`
    /// 3. Rule matched & browser missing → `.showWarning(matchedRule)`
    /// 4a. No match & openInBrowser & browser installed → `.openBrowser(browserId)`
    /// 4b. No match & openInBrowser & browser missing → `.showDefaultBrowserWarning(browserId)`
    /// 5. No match & showPicker → `.showPicker`
    /// 6. No match & doNothing → `.doNothing`
    static func resolve(
        matchedRule: BrowserRule?,
        browserInstalled: Bool,
        defaultBehavior: AppSettings.DefaultBehavior,
        defaultBrowserInstalled: Bool = true,
        forceShowPicker: Bool
    ) -> RouteAction {
        // ⌘-click always forces the picker
        if forceShowPicker {
            return .showPicker
        }

        // Rule matched
        if let rule = matchedRule {
            if browserInstalled {
                return .openBrowser(browserId: rule.browserId)
            } else {
                return .showWarning(matchedRule: rule)
            }
        }

        // No rule match — fall back to default behavior
        switch defaultBehavior {
        case .showPicker:
            return .showPicker
        case .openInBrowser(let browserId):
            if defaultBrowserInstalled {
                return .openBrowser(browserId: browserId)
            } else {
                return .showDefaultBrowserWarning(browserId: browserId)
            }
        case .doNothing:
            return .doNothing
        }
    }
}
