# BrowserRouter

[中文文档](README_CN.md)

A lightweight macOS app that routes URLs to different browsers based on rules you define. Click a link anywhere, and it opens in the right browser — automatically.

## Features

- **Rule-based routing** — Define wildcard patterns to match URLs and assign them to specific browsers
- **Dock-style browser picker** — When no rule matches, a frosted-glass floating picker appears at your cursor
- **Wildcard patterns** — `*` matches a single level, `**` matches multiple levels including paths and subdomains
- **Path & query matching** — Rules can match URL paths (`*.foo.com/bar**`) and query parameters (`*.foo.com?id=**`)
- **Incognito mode** — Hold your cursor over a browser icon to switch to private/incognito mode before clicking (supports Chrome, Edge, Firefox, Brave, Vivaldi, Opera, Yandex, Tor Browser)
- **⌘-click override** — Hold ⌘ when clicking any link to force the browser picker, bypassing all rules
- **Browser ordering & hiding** — Reorder and hide browsers in the picker via Preferences
- **Quick-add rules** — Add rules directly from the browser picker without opening Preferences
- **URL test tool** — Test URLs against your rules in the Rules tab to verify matching behavior
- **Click statistics** — Track how often each browser is used
- **Multi-language** — English, 简体中文, 繁體中文, 日本語 (can override system language)
- **Launch at login** — Runs silently in the menu bar

## Supported Browsers

Safari, Google Chrome, Chrome Canary, Chromium, Firefox, Microsoft Edge, Arc, Brave, Opera, Opera GX, Vivaldi, Yandex, DuckDuckGo, Tor Browser, UC Browser, Quark, 360, Orion

## Wildcard Pattern Reference

| Pattern | Matches | Doesn't Match |
|---------|---------|---------------|
| `*.foo.com` | `bar.foo.com` | `a.b.foo.com` |
| `**.foo.com` | `bar.foo.com`, `a.b.c.foo.com` | |
| `*.foo.com/bar` | `x.foo.com/bar` | `x.foo.com/bar/baz` |
| `*.foo.com/bar**` | `x.foo.com/bar`, `x.foo.com/bar/baz` | |
| `*.foo.com/api?id=**` | `.../api?id=123` | `.../api?x=1` |

- `*` — matches a single level (no `.` or `/`)
- `**` — matches zero or more characters of anything (including `.` and `/`)
- Without `?` in the pattern, query parameters are ignored during matching

## Installation

### Option 1: One-line install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/phpgao/BrowserRouter/main/install.sh | bash -s -- "https://github.com/phpgao/BrowserRouter/releases/latest/download/BrowserRouter.zip"
```

### Option 2: Manual install

1. Download `BrowserRouter.zip` from [Releases](https://github.com/phpgao/BrowserRouter/releases)
2. Unzip and drag `BrowserRouter.app` to `/Applications`
3. Remove quarantine attribute (required for unsigned apps):
   ```bash
   xattr -cr /Applications/BrowserRouter.app
   ```
4. Open `BrowserRouter.app`

### Option 3: Right-click open

1. Drag to `/Applications`
2. Right-click → Open → Click "Open" in the dialog (only needed once)

## Build from Source

Requires Xcode 15+ and macOS 14+.

```bash
git clone https://github.com/phpgao/BrowserRouter.git
cd BrowserRouter
xcodebuild -scheme BrowserRouter -configuration Release build CONFIGURATION_BUILD_DIR=/Applications
```

Or use the packaging script:

```bash
./package.sh   # Outputs dist/BrowserRouter.zip
```

## Usage

1. Launch BrowserRouter — it appears as a menu bar icon
2. Set it as your default browser in Preferences → System
3. Add URL rules in Preferences → Rules
4. Click any link — it routes to the matching browser automatically

**Tips:**
- Hold `⌘` when clicking a link to force the browser picker
- Hover over a browser icon in the picker to activate incognito mode
- Use the URL test tool in the Rules tab to verify your patterns

## License

GPLv3
