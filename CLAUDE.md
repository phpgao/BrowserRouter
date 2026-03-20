# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BrowserRouter is a macOS app (SwiftUI, minimum macOS 13, Swift 6 language mode) that acts as the system default browser and routes URLs to different browsers based on user-defined wildcard pattern rules. Uses Sparkle 2.x for auto-updates; no other external dependencies.

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
- **Core/** — Stateless services: `URLRouter` (pattern→regex compiler, pure functions), `RouteResolver` (pure routing decision logic), `BrowserManager` (detect/launch browsers), `RuleStore` (JSON + UserDefaults persistence), `AppStateStore` (ObservableObject bridge to SwiftUI)
- **Models/** — `BrowserRule` (pattern + browserId + isEnabled), `Browser`, `AppSettings` (with custom Codable for enum with associated values)
- **UI/** — SwiftUI views: `RulesListView`, `AddRulesSheet`, `BrowserPickerView`, `FloatingPickerWindow` (NSPanel subclass for cursor-positioned picker), `GeneralSettingsView`, `BrowsersSettingsView`

### Key Data Flow

```
URL intercepted → AppDelegate.application(_:open:)
  → URLRouter.match(url)        // first enabled matching rule wins
  → RouteResolver.resolve(...)  // pure decision: openBrowser | showPicker | showWarning | doNothing
  → AppDelegate handles action  // side effects: BrowserManager.open, showPicker, alert
  → fallback: AppSettings.defaultBehavior (showPicker | openInBrowser | doNothing)
```

State management: `AppStateStore` (@Published) → SwiftUI views. Changes save via `RuleStore` and post `Notification.Name.settingsDidChange` for non-UI consumers (StatusBarController, AppDelegate).

### Pattern Engine (URLRouter)

Wildcard patterns compiled to `NSRegularExpression`: `*` → `[^/.]+` (single level), `**` → `.+` (multi-level including `/` and `.`). Pattern matching considers host-only vs path vs query based on whether the pattern contains `/` or `?`. The `URLRouter` class is `nonisolated` — safe to use off MainActor.

### Route Decision (RouteResolver)

`RouteResolver.resolve()` is a pure function (no side effects) that determines the routing action:
1. `forceShowPicker` (⌘-click) → `.showPicker`
2. Rule matched & browser installed → `.openBrowser(browserId)`
3. Rule matched & browser missing → `.showWarning(matchedRule)` — shows alert, user can choose alternate browser which updates the rule
4. No match → delegates to `AppSettings.defaultBehavior`

## Internationalization

Uses Xcode String Catalogs (`Localizable.xcstrings`). Four languages: en (source), zh-Hans, zh-Hant, ja. All user-facing strings must use `NSLocalizedString()` or SwiftUI's automatic `Text("key")` localization. When adding new UI strings, add translations for all four languages in the xcstrings file.

## Testing

XCTest with 8 suites in `BrowserRouterTests/`: URLRouterTests (pattern matching, normalization, query patterns), RuleStoreTests (persistence round-trip, click stats), PatternValidationTests (input validation), AppSettingsTests (Codable), BrowserManagerTests (detection, properties), RouteResolverTests (all routing decision paths), AppStateStoreTests (CRUD, import/export, browser order), ImportExportTests (merge/replace). URLRouter and RouteResolver tests are the most critical — any pattern engine or routing changes must pass all existing tests.

## Post-Change Workflow

After completing any feature changes, always follow this order:
1. Run all tests and ensure they pass: `xcodebuild test -scheme BrowserRouter -destination 'platform=macOS'`
2. Package and deploy to `/Applications` for manual testing:
```bash
./package.sh && rm -rf /Applications/BrowserRouter.app && unzip -o dist/BrowserRouter.zip -d /Applications && xattr -cr /Applications/BrowserRouter.app
```

## Persistence

- Rules: `~/Library/Application Support/BrowserRouter/rules.json`
- Settings: `UserDefaults(suiteName: "BrowserRouterAppSettings")`
- Click stats: `UserDefaults(suiteName: "BrowserRouterClickStats")`

## Release Workflow

1. Update version in Xcode project (Marketing Version + Build Number)
2. Commit, tag, and push:
   ```bash
   git tag v1.x.x && git push origin v1.x.x
   ```
3. GitHub Actions will automatically:
   - Build universal binary
   - Sign with Sparkle EdDSA key
   - Update appcast.xml
   - Create GitHub Release with SHA256 in body
4. Or manually:
   ```bash
   ./package.sh
   # Use Sparkle's sign_update to sign, then update appcast.xml
   # Create GitHub release
   ```

## Update Mechanism

Uses Sparkle 2.x framework. Update feed (appcast.xml) hosted in the repo,
served via raw.githubusercontent.com. Updates are verified with EdDSA (Ed25519)
signatures. The Sparkle private key is stored as a GitHub Secret
(SPARKLE_PRIVATE_KEY) for CI and in the local Keychain for manual releases.
