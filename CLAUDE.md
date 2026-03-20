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

1. Update `MARKETING_VERSION` in `project.pbxproj` (all 4 occurrences) to the new version
2. Commit and push to main:
   ```bash
   git add -A && git commit -m "feat: description (vX.Y.Z)"
   ```
3. Tag and push:
   ```bash
   git tag vX.Y.Z && git push origin main --tags
   ```
4. GitHub Actions (`release.yml`) automatically:
   - Builds universal binary via `package.sh`
   - Build number = total git commit count (monotonically increasing)
   - Generates release notes from git log since last tag
   - Downloads Sparkle tools and signs the zip with EdDSA
   - Updates `appcast.xml` with version, build number, signature, and release notes
   - Commits `appcast.xml` back to main
   - Creates GitHub Release with changelog and SHA256
5. Users running BrowserRouter will see the update via Sparkle (auto-check or manual "Check for Updates…")

### Manual release (without CI):
```bash
./package.sh
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -path '*/sparkle/Sparkle/bin/sign_update' -print -quit)
$SIGN_UPDATE dist/BrowserRouter.zip
python3 scripts/update_appcast.py --version "X.Y.Z" --build "$(git rev-list --count HEAD)" \
  --signature "SIGNATURE" --notes "Release notes here" --file dist/BrowserRouter.zip
```

## Update Mechanism

Uses Sparkle 2.x framework. Update feed (`appcast.xml`) hosted in the repo,
served via `raw.githubusercontent.com`. Updates are verified with EdDSA (Ed25519)
signatures. The Sparkle private key is stored as a GitHub Secret
(`SPARKLE_PRIVATE_KEY`) for CI and in the local Keychain for manual releases.

Key files:
- `appcast.xml` — Sparkle update feed (auto-updated by CI on each release)
- `scripts/update_appcast.py` — Script to add new version entries to appcast
- `.github/workflows/release.yml` — CI release workflow triggered by `v*` tags
- `BrowserRouter/Info.plist` — Contains `SUFeedURL` and `SUPublicEDKey`
- `BrowserRouter/UI/StatusBarController.swift` — Sparkle `SPUStandardUpdaterController` integration
