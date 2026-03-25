# Default Browser Missing Warning

When the user's fallback behavior is set to "open in a specific browser" and that browser has been uninstalled, clicking a link should warn the user and let them pick a replacement — rather than silently failing.

## Current Behavior

`RouteResolver.resolve()` handles the no-rule-match + `defaultBehavior == .openInBrowser(browserId)` case by returning `.openBrowser(browserId)` unconditionally. If the browser no longer exists, `BrowserManager.open()` fails silently.

Rule-matched routing already checks `browserInstalled` and returns `.showWarning(matchedRule)` when the browser is missing. The fallback path lacks the same safety net.

## Design

### 1. RouteAction — new case

```swift
case showDefaultBrowserWarning(browserId: String)
```

Carries the missing browser's ID so the alert can display its name.

### 2. RouteResolver — new parameter and logic

Signature adds `defaultBrowserInstalled: Bool`:

```swift
static func resolve(
    matchedRule: BrowserRule?,
    browserInstalled: Bool,
    defaultBehavior: AppSettings.DefaultBehavior,
    defaultBrowserInstalled: Bool,
    forceShowPicker: Bool
) -> RouteAction
```

The `case .openInBrowser` branch becomes:

```swift
case .openInBrowser(let browserId):
    if defaultBrowserInstalled {
        return .openBrowser(browserId: browserId)
    } else {
        return .showDefaultBrowserWarning(browserId: browserId)
    }
```

All other paths are unchanged. The function remains pure.

### 3. AppDelegate — handle new action

Follows the same two-step UX as the existing rule-matched browser-missing warning (alert → FloatingPicker) for consistency.

New method `showDefaultBrowserMissingAlert(for:browserId:)`:

- NSAlert with `.warning` style
- Title: "Default Browser Not Found"
- Message: "The default fallback browser "%@" is no longer installed.\n\nWould you like to choose a replacement browser?"
- The `%@` displays the `browserId` string directly (the browser is uninstalled so its display name is unavailable)
- Two buttons: "Choose Browser", "Cancel"

On "Choose Browser":
1. Show FloatingPickerWindow (reuse `showPicker` flow)
2. When user picks a browser: open the URL in that browser AND update `settings.defaultBehavior` to `.openInBrowser(newBrowserId)`, persist via `ruleStore.save(settings:)` + `reloadSettings()`

On "Cancel":
- The URL is discarded (same behavior as existing rule-matched browser-missing alert)

### 4. AppDelegate.route() — call-site change

```swift
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
```

New switch case:

```swift
case .showDefaultBrowserWarning(let browserId):
    showDefaultBrowserMissingAlert(for: url, browserId: browserId)
```

### 5. Tests

In `RouteResolverTests`:

**New tests (core path):**

| Test | Input | Expected |
|------|-------|----------|
| `test_noMatch_openInBrowser_installed` | no rule, `.openInBrowser("X")`, defaultBrowserInstalled=true | `.openBrowser(browserId: "X")` |
| `test_noMatch_openInBrowser_missing` | no rule, `.openInBrowser("X")`, defaultBrowserInstalled=false | `.showDefaultBrowserWarning(browserId: "X")` |

**Regression tests (new param doesn't affect unrelated paths):**

| Test | Input | Expected |
|------|-------|----------|
| `test_noMatch_showPicker_defaultBrowserInstalledFalse` | no rule, `.showPicker`, defaultBrowserInstalled=false | `.showPicker` |
| `test_noMatch_doNothing_defaultBrowserInstalledFalse` | no rule, `.doNothing`, defaultBrowserInstalled=false | `.doNothing` |
| `test_forceShowPicker_ignoresDefaultBrowserMissing` | has rule, forceShowPicker=true, defaultBrowserInstalled=false | `.showPicker` |
| `test_ruleMatch_browserInstalled_ignoresDefaultBrowserMissing` | rule matched, browserInstalled=true, defaultBrowserInstalled=false | `.openBrowser` |

**Existing tests:** All existing `RouteResolverTests` add `defaultBrowserInstalled: true` to their `resolve()` calls.

### 6. Internationalization

New strings in `Localizable.xcstrings` for en, zh-Hans, zh-Hant, ja:

| Key | en | zh-Hans | zh-Hant | ja |
|-----|----|---------|---------|----|
| "Default Browser Not Found" | Default Browser Not Found | 默认浏览器未找到 | 預設瀏覽器未找到 | デフォルトブラウザが見つかりません |
| "The default fallback browser \"%@\" is no longer installed.\n\nWould you like to choose a replacement browser?" | (same) | 默认后备浏览器「%@」已不存在。\n\n是否选择替代浏览器？ | 預設後備瀏覽器「%@」已不存在。\n\n是否選擇替代瀏覽器？ | デフォルトのフォールバックブラウザ「%@」はインストールされていません。\n\n代替ブラウザを選択しますか？ |

## Edge Cases

- **`forceShowPicker` takes priority**: ⌘-click always returns `.showPicker` regardless of default browser state.
- **Rule-matched path unaffected**: When a rule matches, the existing `browserInstalled` check handles browser-missing; `defaultBrowserInstalled` is irrelevant.
- **Cancel discards the URL**: Same behavior as the existing rule-matched browser-missing alert.
- **Browser name display**: Since the browser is uninstalled, `BrowserManager.browser(forId:)` returns nil. The alert displays the raw `browserId` (e.g., `com.google.Chrome`). This is acceptable as the user will recognize the identifier.
- **Multiple URLs at once**: If N URLs arrive simultaneously, N alerts may appear. This matches existing behavior for rule-matched warnings. Future optimization (dedup/batch) is out of scope.

## Files Changed

| File | Change |
|------|--------|
| `BrowserRouter/Core/RouteResolver.swift` | New `RouteAction` case, new parameter, branching logic |
| `BrowserRouter/App/AppDelegate.swift` | New alert method, updated `route()` call-site |
| `BrowserRouterTests/RouteResolverTests.swift` | Two new tests, existing tests updated for new parameter |
| `BrowserRouter/Localizable.xcstrings` | New localized strings (4 languages) |
