# BrowserRouter

一款轻量级 macOS 应用，根据你定义的规则将 URL 路由到不同的浏览器。点击链接，自动用正确的浏览器打开。

## 功能特性

- **规则路由** — 定义通配符模式匹配 URL，指定对应的浏览器
- **Dock 风格浏览器选择器** — 无匹配规则时，在光标位置弹出毛玻璃浮窗供你选择
- **通配符模式** — `*` 匹配单级域名，`**` 匹配多级域名、路径和子路径
- **路径与参数匹配** — 规则可匹配 URL 路径（`*.foo.com/bar**`）和查询参数（`*.foo.com?id=**`）
- **隐身模式** — 在选择器中将光标悬停在浏览器图标上，切换至隐身/无痕模式（支持 Chrome、Edge、Firefox、Brave、Vivaldi、Opera、Yandex、Tor Browser）
- **⌘ 点击强制选择** — 按住 ⌘ 键点击链接，跳过所有规则，强制弹出浏览器选择器
- **浏览器排序与隐藏** — 在偏好设置中拖拽排序、勾选隐藏不需要的浏览器
- **快速添加规则** — 直接在浏览器选择器中添加规则，无需打开偏好设置
- **URL 测试工具** — 在规则页面输入 URL 测试匹配结果，验证规则是否生效
- **点击统计** — 记录每个浏览器的使用次数
- **多语言** — 支持 English、简体中文、繁體中文、日本語（可独立于系统语言设置）
- **开机自启** — 静默运行在菜单栏

## 支持的浏览器

Safari、Google Chrome、Chrome Canary、Chromium、Firefox、Microsoft Edge、Arc、Brave、Opera、Opera GX、Vivaldi、Yandex、DuckDuckGo、Tor Browser、UC 浏览器、夸克浏览器、360、Orion

## 通配符规则参考

| 规则 | 匹配 | 不匹配 |
|------|------|--------|
| `*.foo.com` | `bar.foo.com` | `a.b.foo.com` |
| `**.foo.com` | `bar.foo.com`、`a.b.c.foo.com` | |
| `*.foo.com/bar` | `x.foo.com/bar` | `x.foo.com/bar/baz` |
| `*.foo.com/bar**` | `x.foo.com/bar`、`x.foo.com/bar/baz` | |
| `*.foo.com/api?id=**` | `.../api?id=123` | `.../api?x=1` |

- `*` — 匹配单级（不含 `.` 和 `/`）
- `**` — 匹配零个或多个任意字符（包含 `.` 和 `/`）
- 规则中不含 `?` 时，查询参数在匹配时被忽略

## 安装

### 方式一：一行命令安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/phpgao/BrowserRouter/main/install.sh | bash -s -- "https://github.com/phpgao/BrowserRouter/releases/latest/download/BrowserRouter.zip"
```

### 方式二：手动安装

1. 从 [Releases](https://github.com/phpgao/BrowserRouter/releases) 下载 `BrowserRouter.zip`
2. 解压后将 `BrowserRouter.app` 拖入 `/Applications`
3. 移除隔离属性（未签名应用需要此步骤）：
   ```bash
   xattr -cr /Applications/BrowserRouter.app
   ```
4. 打开 `BrowserRouter.app`

### 方式三：右键打开

1. 拖入 `/Applications`
2. 右键 → 打开 → 在弹窗中点击"打开"（仅首次需要）

## 从源码构建

需要 Xcode 15+ 和 macOS 14+。

```bash
git clone https://github.com/phpgao/BrowserRouter.git
cd BrowserRouter
xcodebuild -scheme BrowserRouter -configuration Release build CONFIGURATION_BUILD_DIR=/Applications
```

或使用打包脚本：

```bash
./package.sh   # 输出 dist/BrowserRouter.zip
```

## 使用方法

1. 启动 BrowserRouter — 菜单栏出现图标
2. 在偏好设置 → 系统中设为默认浏览器
3. 在偏好设置 → 规则中添加 URL 规则
4. 点击任意链接 — 自动路由到匹配的浏览器

**小技巧：**
- 按住 `⌘` 点击链接可强制弹出浏览器选择器
- 在选择器中悬停浏览器图标可激活隐身模式
- 在规则页面使用 URL 测试工具验证规则匹配

## 许可证

GPLv3
