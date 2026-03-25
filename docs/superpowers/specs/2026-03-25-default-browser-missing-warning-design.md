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

New method `showDefaultBrowserMissingAlert(for:browserId:)`:

- NSAlert with `.warning` style
- Title: "Default Browser Not Found"
- Message: "The default fallback browser "%@" is no longer installed. Please choose a replacement."
- An accessory view containing an NSPopUpButton listing all installed browsers
- Two buttons: "Select & Open", "Cancel"

On "Select & Open":
1. Open the URL in the selected browser
2. Update `settings.defaultBehavior` to `.openInBrowser(newBrowserId)` and persist via `ruleStore.save(settings:)` + `reloadSettings()`

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

| Test | Input | Expected |
|------|-------|----------|
| `test_noMatch_openInBrowser_installed` | no rule, `.openInBrowser("X")`, defaultBrowserInstalled=true | `.openBrowser(browserId: "X")` |
| `test_noMatch_openInBrowser_missing` | no rule, `.openInBrowser("X")`, defaultBrowserInstalled=false | `.showDefaultBrowserWarning(browserId: "X")` |

Existing tests pass `defaultBrowserInstalled: true` (their fallback paths don't exercise `.openInBrowser` with missing browser).

### 6. Internationalization

New strings in `Localizable.xcstrings` for en, zh-Hans, zh-Hant, ja:

| Key | en | zh-Hans | zh-Hant | ja |
|-----|----|---------|---------|----|
| "Default Browser Not Found" | Default Browser Not Found | 默认浏览器未找到 | 預設瀏覽器未找到 | デフォルトブラウザが見つかりません |
| "The default fallback browser \"%@\" is no longer installed.\n\nPlease choose a replacement browser:" | (same) | 默认后备浏览器「%@」已不存在。\n\n请选择替代浏览器： | 預設後備瀏覽器「%@」已不存在。\n\n請選擇替代瀏覽器： | デフォルトのフォールバックブラウザ「%@」はインストールされていません。\n\n代替ブラウザを選択してください： |
| "Select & Open" | Select & Open | 选择并打开 | 選擇並開啟 | 選択して開く |

## Files Changed

| File | Change |
|------|--------|
| `BrowserRouter/Core/RouteResolver.swift` | New `RouteAction` case, new parameter, branching logic |
| `BrowserRouter/App/AppDelegate.swift` | New alert method, updated `route()` call-site |
| `BrowserRouterTests/RouteResolverTests.swift` | Two new tests, existing tests updated for new parameter |
| `BrowserRouter/Localizable.xcstrings` | New localized strings (4 languages) |
