# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BrowserRouter is a macOS app (SwiftUI, minimum macOS 13) that acts as the system default browser and routes URLs to different browsers based on user-defined wildcard pattern rules. Zero external dependencies — pure native implementation.

## Build & Test Commands

```bash
# Debug build
xcodebuild build -scheme BrowserRouter -destination 'platform=macOS'

# Release build (universal binary: arm64 + x86_64)
xcodebuild build -scheme BrowserRouter -destination 'generic/platform=macOS' \
  -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO

# Run all tests
xcodebuild test -scheme BrowserRouter -destination 'platform=macOS'

# Package for distribution (outputs dist/BrowserRouter.zip)
./package.sh
```

Single test filtering is via `-only-testing`:
```bash
xcodebuild test -scheme BrowserRouter -destination 'platform=macOS' \
  -only-testing:BrowserRouterTests/URLRouterTests/test_matches_singleWildcard
```

## Architecture

Four-layer structure under `BrowserRouter/`:

- **App/** — `AppDelegate` (URL intercept entry point, wires everything), `BrowserRouterApp` (SwiftUI lifecycle)
- **Core/** — Stateless services: `URLRouter` (pattern→regex compiler, pure functions), `BrowserManager` (detect/launch browsers), `RuleStore` (JSON + UserDefaults persistence), `AppStateStore` (ObservableObject bridge to SwiftUI)
- **Models/** — `BrowserRule` (pattern + browserId + isEnabled), `Browser`, `AppSettings` (with custom Codable for enum with associated values)
- **UI/** — SwiftUI views: `RulesListView`, `AddRulesSheet`, `BrowserPickerView`, `FloatingPickerWindow` (NSPanel subclass for cursor-positioned picker), `GeneralSettingsView`, `BrowsersSettingsView`

### Key Data Flow

```
URL intercepted → AppDelegate.application(_:open:)
  → URLRouter.match(url)        // first enabled matching rule wins
  → BrowserManager.open(url, browserId)
  → fallback: AppSettings.defaultBehavior (showPicker | openInBrowser | doNothing)
```

State management: `AppStateStore` (@Published) → SwiftUI views. Changes save via `RuleStore` and post `Notification.Name.settingsDidChange` for non-UI consumers (StatusBarController, AppDelegate).

### Pattern Engine (URLRouter)

Wildcard patterns compiled to `NSRegularExpression`: `*` → `[^/.]+` (single level), `**` → `.+` (multi-level including `/` and `.`). Pattern matching considers host-only vs path vs query based on whether the pattern contains `/` or `?`. The `URLRouter` class is `nonisolated` — safe to use off MainActor.

## Internationalization

Uses Xcode String Catalogs (`Localizable.xcstrings`). Four languages: en (source), zh-Hans, zh-Hant, ja. All user-facing strings must use `NSLocalizedString()` or SwiftUI's automatic `Text("key")` localization. When adding new UI strings, add translations for all four languages in the xcstrings file.

## Testing

XCTest with 5 suites in `BrowserRouterTests/`: URLRouterTests (pattern matching, normalization), RuleStoreTests (persistence round-trip), PatternValidationTests (input validation), AppSettingsTests (Codable), BrowserManagerTests (detection). URLRouter tests are the most critical — any pattern engine changes must pass all existing tests.

## Persistence

- Rules: `~/Library/Application Support/BrowserRouter/rules.json`
- Settings: `UserDefaults(suiteName: "BrowserRouterAppSettings")`
- Click stats: `UserDefaults(suiteName: "BrowserRouterClickStats")`
