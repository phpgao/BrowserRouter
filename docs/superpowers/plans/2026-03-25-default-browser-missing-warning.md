# Default Browser Missing Warning — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the fallback behavior targets a browser that has been uninstalled, warn the user and let them pick a replacement via the existing FloatingPicker flow.

**Architecture:** Add a new `RouteAction.showDefaultBrowserWarning(browserId:)` case. `RouteResolver.resolve()` gains a `defaultBrowserInstalled` parameter to check browser existence on the fallback path. `AppDelegate` handles the new action with an alert → picker flow that also updates the persisted `defaultBehavior` setting.

**Tech Stack:** Swift 6, SwiftUI, XCTest, Xcode String Catalogs

**Spec:** `docs/superpowers/specs/2026-03-25-default-browser-missing-warning-design.md`

---

### Task 1: RouteResolver — add new action case and parameter

**Files:**
- Modify: `BrowserRouter/Core/RouteResolver.swift:11-16` (RouteAction enum)
- Modify: `BrowserRouter/Core/RouteResolver.swift:28-57` (resolve function)

- [ ] **Step 1: Add new RouteAction case**

In `RouteResolver.swift`, add after line 15:

```swift
case showDefaultBrowserWarning(browserId: String)  // fallback browser missing
```

- [ ] **Step 2: Add `defaultBrowserInstalled` parameter and update logic**

Update `resolve()` signature — use default value `= true` so existing callers (AppDelegate, tests) keep compiling until they're updated:

```swift
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
```

- [ ] **Step 3: Update doc comment**

Update the decision tree comment to include step 4b:

```swift
/// Decision tree:
/// 1. `forceShowPicker` → `.showPicker`
/// 2. Rule matched & browser installed → `.openBrowser(rule.browserId)`
/// 3. Rule matched & browser missing → `.showWarning(matchedRule)`
/// 4a. No match & openInBrowser & browser installed → `.openBrowser(browserId)`
/// 4b. No match & openInBrowser & browser missing → `.showDefaultBrowserWarning(browserId)`
/// 5. No match & showPicker → `.showPicker`
/// 6. No match & doNothing → `.doNothing`
```

- [ ] **Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme BrowserRouter -destination 'platform=macOS' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED (default value `= true` keeps existing callers compiling)

- [ ] **Step 5: Commit**

```bash
git add BrowserRouter/Core/RouteResolver.swift
git commit -m "feat: add showDefaultBrowserWarning RouteAction and defaultBrowserInstalled param"
```

---

### Task 2: Update existing tests for new parameter + add new tests

**Files:**
- Modify: `BrowserRouterTests/RouteResolverTests.swift`

- [ ] **Step 1: Update all existing resolve() calls to include `defaultBrowserInstalled: true`**

Every existing call to `RouteResolver.resolve(...)` in `RouteResolverTests.swift` needs the new parameter. Add `defaultBrowserInstalled: true` before `forceShowPicker:` in each call. There are 7 calls total:

1. `test_forceShowPicker_alwaysShowsPicker` (line 29)
2. `test_ruleMatch_browserInstalled_opensBrowser` (line 42)
3. `test_ruleMatch_browserMissing_showsWarning` (line 52)
4. `test_noMatch_defaultShowPicker` (line 65)
5. `test_noMatch_defaultOpenInBrowser` (line 75)
6. `test_noMatch_defaultDoNothing` (line 84)
7. `test_disabledRule_noMatch_fallsToDefault` (line 98)

- [ ] **Step 2: Add core test — default browser installed**

```swift
func test_noMatch_openInBrowser_installed() {
    let action = RouteResolver.resolve(
        matchedRule: nil,
        browserInstalled: false,
        defaultBehavior: .openInBrowser("com.apple.Safari"),
        defaultBrowserInstalled: true,
        forceShowPicker: false
    )
    XCTAssertEqual(action, .openBrowser(browserId: "com.apple.Safari"))
}
```

- [ ] **Step 3: Add core test — default browser missing**

```swift
func test_noMatch_openInBrowser_missing() {
    let action = RouteResolver.resolve(
        matchedRule: nil,
        browserInstalled: false,
        defaultBehavior: .openInBrowser("com.deleted.Browser"),
        defaultBrowserInstalled: false,
        forceShowPicker: false
    )
    XCTAssertEqual(action, .showDefaultBrowserWarning(browserId: "com.deleted.Browser"))
}
```

- [ ] **Step 4: Add regression tests — new param doesn't affect unrelated paths**

```swift
// MARK: - Default Browser Missing (regression — unrelated paths unaffected)

func test_noMatch_showPicker_defaultBrowserInstalledFalse() {
    let action = RouteResolver.resolve(
        matchedRule: nil,
        browserInstalled: false,
        defaultBehavior: .showPicker,
        defaultBrowserInstalled: false,
        forceShowPicker: false
    )
    XCTAssertEqual(action, .showPicker)
}

func test_noMatch_doNothing_defaultBrowserInstalledFalse() {
    let action = RouteResolver.resolve(
        matchedRule: nil,
        browserInstalled: false,
        defaultBehavior: .doNothing,
        defaultBrowserInstalled: false,
        forceShowPicker: false
    )
    XCTAssertEqual(action, .doNothing)
}

func test_forceShowPicker_ignoresDefaultBrowserMissing() {
    let rule = makeRule()
    let action = RouteResolver.resolve(
        matchedRule: rule,
        browserInstalled: true,
        defaultBehavior: .openInBrowser("com.deleted.Browser"),
        defaultBrowserInstalled: false,
        forceShowPicker: true
    )
    XCTAssertEqual(action, .showPicker)
}

func test_ruleMatch_browserInstalled_ignoresDefaultBrowserMissing() {
    let rule = makeRule(browserId: "com.google.Chrome")
    let action = RouteResolver.resolve(
        matchedRule: rule,
        browserInstalled: true,
        defaultBehavior: .openInBrowser("com.deleted.Browser"),
        defaultBrowserInstalled: false,
        forceShowPicker: false
    )
    XCTAssertEqual(action, .openBrowser(browserId: "com.google.Chrome"))
}
```

- [ ] **Step 5: Run tests to verify they still pass**

Run: `xcodebuild test -scheme BrowserRouter -destination 'platform=macOS' 2>&1 | grep -E '(Test Suite|Executed|FAIL)'`

Expected: All existing tests pass (default value `= true` means old tests are unaffected).

- [ ] **Step 6: Commit**

```bash
git add BrowserRouterTests/RouteResolverTests.swift
git commit -m "test: update RouteResolverTests for defaultBrowserInstalled param + add new tests"
```

---

### Task 3: AppDelegate — update route() and add new alert handler

**Files:**
- Modify: `BrowserRouter/App/AppDelegate.swift:114-134` (route method)
- Modify: `BrowserRouter/App/AppDelegate.swift:142-161` (add new alert method after existing one)

- [ ] **Step 1: Update `route()` to compute `defaultBrowserInstalled` and pass it**

Replace the `route(url:)` method body (lines 114-134):

```swift
private func route(url: URL) {
    let matched = urlRouter?.match(url)
    let browserInstalled = matched.map { browserManager.browser(forId: $0.browserId) != nil } ?? false
    let defaultBrowserInstalled: Bool = {
        if case .openInBrowser(let id) = settings.defaultBehavior {
            return browserManager.browser(forId: id) != nil
        }
        return true  // irrelevant for showPicker / doNothing
    }()
    let action = RouteResolver.resolve(
        matchedRule: matched,
        browserInstalled: browserInstalled,
        defaultBehavior: settings.defaultBehavior,
        defaultBrowserInstalled: defaultBrowserInstalled,
        forceShowPicker: NSEvent.modifierFlags.contains(.command)
    )

    switch action {
    case .openBrowser(let browserId):
        openAndRecord(url: url, browserId: browserId, isIncognito: false)
    case .showPicker:
        showPicker(for: url)
    case .showWarning(let rule):
        showBrowserMissingAlert(for: url, rule: rule)
    case .showDefaultBrowserWarning(let browserId):
        showDefaultBrowserMissingAlert(for: url, browserId: browserId)
    case .doNothing:
        break
    }
}
```

- [ ] **Step 2: Add `showDefaultBrowserMissingAlert` method**

Add after the existing `showBrowserMissingAlert` method (after line 161):

```swift
// MARK: - Default Browser Missing Alert

private func showDefaultBrowserMissingAlert(for url: URL, browserId: String) {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString("Default Browser Not Found", comment: "")
    alert.informativeText = String(
        format: NSLocalizedString(
            "The default fallback browser \"%@\" is no longer installed.\n\nWould you like to choose a replacement browser?",
            comment: ""
        ),
        browserId
    )
    alert.alertStyle = .warning
    alert.addButton(withTitle: NSLocalizedString("Choose Browser", comment: ""))
    alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))

    NSApp.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        showDefaultBrowserPicker(for: url)
    }
}

/// Shows the browser picker for the default-browser-missing scenario.
/// When the user picks a browser, opens the URL AND updates defaultBehavior setting.
private func showDefaultBrowserPicker(for url: URL) {
    let cursorPosition = NSEvent.mouseLocation
    let browsers = store.visibleBrowsers

    pickerWindow = FloatingPickerWindow(
        browsers: browsers,
        atPosition: cursorPosition,
        showQuickAdd: false,
        incognitoHoverEnabled: settings.incognitoHoverEnabled,
        incognitoHoverDelay: settings.incognitoHoverDelay,
        onSelect: { [weak self] browserId, isIncognito in
            guard let self else { return }
            self.openAndRecord(url: url, browserId: browserId, isIncognito: isIncognito)

            // Update defaultBehavior to use the new browser
            var updatedSettings = self.settings
            updatedSettings.defaultBehavior = .openInBrowser(browserId)
            self.ruleStore.save(settings: updatedSettings)
            self.reloadSettings()
        },
        onQuickAdd: { },
        onRuleSaved: nil
    )
    pickerWindow?.show()
}
```

- [ ] **Step 3: Remove default value from `defaultBrowserInstalled` parameter**

In `RouteResolver.swift`, change:
```swift
defaultBrowserInstalled: Bool = true,
```
to:
```swift
defaultBrowserInstalled: Bool,
```

All callers (AppDelegate + tests) now pass the parameter explicitly, so the default is no longer needed.

- [ ] **Step 4: Build and verify compilation**

Run: `xcodebuild build -scheme BrowserRouter -destination 'platform=macOS' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run all tests**

Run: `xcodebuild test -scheme BrowserRouter -destination 'platform=macOS' 2>&1 | grep -E '(Test Suite|Test Case|BUILD|Executed|FAIL)'`

Expected: All tests pass, including the 6 new RouteResolver tests.

- [ ] **Step 6: Commit**

```bash
git add BrowserRouter/App/AppDelegate.swift BrowserRouter/Core/RouteResolver.swift
git commit -m "feat: handle default browser missing with alert and picker flow"
```

---

### Task 4: Internationalization — add localized strings

**Files:**
- Modify: `BrowserRouter/Localizable.xcstrings`

- [ ] **Step 1: Add "Default Browser Not Found" translations**

Add a new entry in the `"strings"` object of `Localizable.xcstrings`:

```json
"Default Browser Not Found": {
  "localizations": {
    "ja": {
      "stringUnit": {
        "state": "translated",
        "value": "デフォルトブラウザが見つかりません"
      }
    },
    "zh-Hans": {
      "stringUnit": {
        "state": "translated",
        "value": "默认浏览器未找到"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "預設瀏覽器未找到"
      }
    }
  }
},
```

- [ ] **Step 2: Add alert message translations**

```json
"The default fallback browser \"%@\" is no longer installed.\n\nWould you like to choose a replacement browser?": {
  "localizations": {
    "ja": {
      "stringUnit": {
        "state": "translated",
        "value": "デフォルトのフォールバックブラウザ「%@」はインストールされていません。\n\n代替ブラウザを選択しますか？"
      }
    },
    "zh-Hans": {
      "stringUnit": {
        "state": "translated",
        "value": "默认后备浏览器「%@」已不存在。\n\n是否选择替代浏览器？"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "預設後備瀏覽器「%@」已不存在。\n\n是否選擇替代瀏覽器？"
      }
    }
  }
},
```

Note: "Choose Browser" and "Cancel" are already used in the existing `showBrowserMissingAlert` — they should already be in xcstrings or will be auto-extracted by Xcode. If "Choose Browser" is missing, add:

```json
"Choose Browser": {
  "localizations": {
    "ja": {
      "stringUnit": {
        "state": "translated",
        "value": "ブラウザを選択"
      }
    },
    "zh-Hans": {
      "stringUnit": {
        "state": "translated",
        "value": "选择浏览器"
      }
    },
    "zh-Hant": {
      "stringUnit": {
        "state": "translated",
        "value": "選擇瀏覽器"
      }
    }
  }
},
```

- [ ] **Step 3: Build to verify strings are valid**

Run: `xcodebuild build -scheme BrowserRouter -destination 'platform=macOS' 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all tests one final time**

Run: `xcodebuild test -scheme BrowserRouter -destination 'platform=macOS' 2>&1 | grep -E '(Test Suite|Test Case|BUILD|Executed|FAIL)'`

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add BrowserRouter/Localizable.xcstrings
git commit -m "i18n: add localized strings for default browser missing alert (en/zh-Hans/zh-Hant/ja)"
```

---

### Task 5: Package and deploy for manual testing

**Files:** None (build/deploy only)

- [ ] **Step 1: Package and deploy**

```bash
cd /Users/jimmy/code/github/BrowserRouter
./package.sh && rm -rf /Applications/BrowserRouter.app && unzip -o dist/BrowserRouter.zip -d /Applications && xattr -cr /Applications/BrowserRouter.app
```

- [ ] **Step 2: Manual test checklist**

1. Open BrowserRouter Settings → General → set fallback to "Open in specific browser" → pick any browser
2. Manually uninstall that browser (or edit UserDefaults to point to a fake browserId)
3. Click a URL that doesn't match any rule
4. Verify: alert appears saying the default browser is not found
5. Click "Choose Browser" → FloatingPicker appears
6. Pick a replacement browser → URL opens in it
7. Verify: Settings now show the new browser as the fallback
8. Click another URL → should open directly in the new browser (no alert)
