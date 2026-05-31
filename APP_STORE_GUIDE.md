# AIFirst macOS App Store 上架指南（个人开发者版）

> 项目路径：`/Users/guoxiujiang/Downloads/同步空间/porject/mac/aifirst`
>
> 本文档基于项目实际代码编写，覆盖从零开始到成功上架 App Store 的完整流程。
> **当前状态**：项目已通过 `xcodegen` 生成了 `aifirst.xcodeproj`，以下指引基于实际工程文件。

---

## 目录

1. [项目概况](#1-项目概况)
2. [前提条件](#2-前提条件)
3. [项目结构说明](#3-项目结构说明)
4. [配置 Info.plist](#4-配置-infoplist)
5. [App 图标](#5-app-图标)
6. [证书与签名配置](#6-证书与签名配置)
7. [App Sandbox 与 Hardened Runtime](#7-app-sandbox-与-hardened-runtime)
8. [App Store Connect 配置](#8-app-store-connect-配置)
9. [构建与归档](#9-构建与归档)
10. [上传到 App Store Connect](#10-上传到-app-store-connect)
11. [提交审核](#11-提交审核)
12. [审核注意事项（关键）](#12-审核注意事项关键)
13. [提审前自查清单](#13-提审前自查清单)
14. [版本更新流程](#14-版本更新流程)
15. [附录：完整速查流程](#15-附录完整速查流程)

---

## 1. 项目概况

**AIFirst** 是一款 macOS 菜单栏 AI 助手，核心功能：

| 功能 | 说明 |
|---|---|
| **AI 聊天** | 与 LLM 自由对话，支持流式输出 |
| **快捷操作** | 翻译、润色、总结、解释代码、扩写 — 选中文本后一键 AI 处理 |
| **自定义动作** | 用户可以自定义 Prompt，创建自己的快捷操作 |
| **多 API 配置** | 支持 DeepSeek、Ollama（localhost）以及任意兼容 OpenAI 格式的 API |
| **全局快捷键** | 使用 Carbon Event API 注册全局热键（Option+Space 打开聊天，Option+Command+L 打开快捷操作面板） |
| **菜单栏集成** | 以菜单栏常驻方式运行（LSUIElement = true），不占用 Dock |
| **多语言** | 简体中文 / 繁體中文 / English，自动跟随系统或手动切换 |
| **系统服务集成** | 在任意 App 中通过右键菜单 → 服务 → AI 翻译/润色/总结/解释代码 直接使用 |

**最低系统版本**：macOS 14.0（项目 Package.swift 中设定）

**个人信息**：开发者姓名 **guoxiujiang**（Apple Developer 个人账号），Organization Identifier 建议使用 `com.guoxj`。

---

## 2. 前提条件

- **Apple Developer Program 个人会员**（$99/年）
  - 注册地址：https://developer.apple.com/programs/
  - 个人账号无需 D-U-N-S 编号
  - 个人账号在 App Store 上开发者名称显示为你的姓名
- **Mac 运行 macOS 14+** 且已安装 **Xcode 16+**
- **Apple ID**（建议使用专用的开发者 Apple ID）
- 项目目录已在本地：`/Users/guoxiujiang/Downloads/同步空间/porject/mac/aifirst`

---

## 3. 项目结构说明

### 3.1 当前工程状态

本项目使用 **xcodegen** 管理 Xcode 工程文件，已生成 `aifirst.xcodeproj`：

```
aifirst/
├── aifirst.xcodeproj/        ← Xcode 工程（已生成，可直接打开）
├── project.yml               ← xcodegen 配置文件（工程定义）
├── Package.swift              ← SwiftPM 清单（仅用于依赖/版本声明）
├── Sources/
│   └── aifirst/
│       ├── AifirstApp.swift   ← App 入口
│       ├── Info.plist         ← App 信息配置文件
│       ├── aifirst.entitlements  ← Entitlements（沙盒权限等）
│       ├── Models/
│       ├── Services/
│       └── Views/
├── APP_STORE_GUIDE.md         ← 本文档
└── .build/                    ← SwiftPM 构建缓存（可删）
```

### 3.2 首次打开 Xcode 工程

```bash
# 直接用 Xcode 打开工程
open aifirst.xcodeproj
```

### 3.3 后续增删文件后重新生成

如果你新增/删除了源文件，或者在 `xcodegen` 尚不支持手动编辑 `project.pbxproj` 场景下需要同步工程，运行：

```bash
# 确保 project.yml 中的 sources 路径正确，然后重新生成
xcodegen generate --project .
```

> **xcodegen 配置（project.yml）管理**：`project.yml` 是整个 Xcode 工程的核心定义。如果需要添加新资源（如 Assets.xcassets）、修改 Build Settings、添加依赖框架，优先编辑 `project.yml` 后重新生成，而非直接在 Xcode GUI 中修改（因为 GUI 修改会被 `xcodegen` 覆盖）。

### 3.4 Xcode 构建系统说明

项目使用 **xcodegen 生成的 Xcode 工程**进行 Archive 提审，`Package.swift` 仅作 Swift 工具版本声明。两者不冲突。

> ⚠️ SwiftPM 构建缓存 `.build/` 在 Xcode 构建过程中不参与，但可能占用空间，提审前建议清理：
> ```bash
> rm -rf .build/
> ```

---

## 4. 配置 Info.plist

### 4.1 补充 Bundle 版本标识

当前 `Info.plist` 缺少 Bundle 版本标识，必须补充以下字段。

在 Xcode 中打开 [`Info.plist`](file:///Users/guoxiujiang/Downloads/同步空间/porject/mac/aifirst/Sources/aifirst/Info.plist)，添加：

| Key | Type | Value |
|---|---|---|
| `CFBundleName` | String | `AIFirst` |
| `CFBundleDisplayName` | String | `AIFirst` |
| `CFBundleIdentifier` | String | `$(PRODUCT_BUNDLE_IDENTIFIER)` |
| `CFBundleVersion` | String | `$(CURRENT_PROJECT_VERSION)` |
| `CFBundleShortVersionString` | String | `$(MARKETING_VERSION)` |
| `NSHumanReadableCopyright` | String | `Copyright © 2026 guoxiujiang. All rights reserved.` |

或直接编辑 Info.plist 源文件，在 `<dict>` 内补充：

```xml
<key>CFBundleName</key>
<string>AIFirst</string>
<key>CFBundleDisplayName</key>
<string>AIFirst</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>CFBundleVersion</key>
<string>$(CURRENT_PROJECT_VERSION)</string>
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>
<key>NSHumanReadableCopyright</key>
<string>Copyright © 2026 guoxiujiang. All rights reserved.</string>
```

### 4.2 关于 NSAppTransportSecurity

当前 Info.plist 已经配置了 ATS（App Transport Security），允许本地 HTTP 连接以支持内网 Ollama 等 API 端点：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>localhost</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

> **提审建议**：当前配置已足够精确，不需要使用 `NSAllowsArbitraryLoads = true`。审核备注中说明用户可配置自定义 API 端点（含本地服务）即可。

---

## 5. App 图标

### 5.1 创建 Assets.xcassets

当前项目没有 `Assets.xcassets` 目录，需要手动创建：

1. 在 Xcode 中打开 `aifirst.xcodeproj`
2. **File → New → File...**（或 `Cmd+N`）
3. 选择 **macOS → Resource → Asset Catalog**
4. 命名为 `Assets`，保存到 `Sources/aifirst/` 目录（与 Info.plist 同级）
5. 确保 **Target Membership** 勾选了 `aifirst`
6. 在 Xcode 导航栏中，打开 `Assets.xcassets`
7. 右键空白区域 → **App Icon & Launch Image → macOS App Icon**
8. 得到 AppIcon 槽位后，拖入各尺寸图标

### 5.2 图标尺寸要求

macOS App Store 需要 **1024×1024** 点（pt）的图标。你可以准备一张 1024×1024 px 的 PNG 源文件。

| 尺寸 | @1x | @2x |
|---|---|---|
| 16×16 | ✅ | ✅ |
| 32×32 | ✅ | ✅ |
| 128×128 | ✅ | ✅ |
| 256×256 | ✅ | ✅ |
| 512×512 | ✅ | ✅ |
| 1024×1024 | — | App Store 必备 |

> **个人开发者建议**：用 Canva / Figma 或 Sketch 设计一个简洁的图标，主题与 AI/聊天相关即可。不需要太复杂。

### 5.3 更新 project.yml（可选，推荐）

如果希望未来 `xcodegen` 重新生成时保留 Assets 引用，在 `project.yml` 中显式声明：

```yaml
targets:
  aifirst:
    sources:
      - path: Sources/aifirst
      - path: Sources/aifirst/Assets.xcassets  # 新增
```

---

## 6. 证书与签名配置

### 6.1 首次配置

1. Xcode 打开 `aifirst.xcodeproj`
2. 点击左侧导航栏顶部 **aifirst** 项目图标
3. 选择 **aifirst target → Signing & Capabilities**
4. 勾选 **Automatically manage signing**
5. **Team**：选择你的个人 Team（如 `guoxiujiang (Personal Team)`）
   - 如果 Team 下拉框为空，说明尚未在 Xcode 中添加 Apple ID：
     - Xcode → Settings → Accounts → + 添加你的 Apple ID
     - 确保该 Apple ID 已加入 Apple Developer Program（$99/年）
6. **Bundle Identifier**：Xcode 自动生成为 `com.guoxj.aifirst`（基于 project.yml 配置）

### 6.2 确认签名配置

签名成功后，Xcode 签名区域应显示：
- **Signing Certificate**: `Apple Development`（调试）/ `Apple Distribution`（发布）
- **Provisioning Profile**: 自动生成

### 6.3 忘记 Register Bundle ID？

首次勾选自动签名时，Xcode 会自动在 Apple Developer Center 注册 Bundle ID。如果遇到 "No profiles for 'com.guoxj.aifirst'" 错误：
1. 登录 [developer.apple.com/account](https://developer.apple.com/account)
2. **Identifiers → + → App IDs → macOS App**
3. Bundle ID 填入 `com.guoxj.aifirst`
4. 回到 Xcode 重新勾选自动签名即可

---

## 7. App Sandbox 与 Hardened Runtime

macOS App Store **必须启用**这两项。

### 7.1 添加 Capabilities

1. 选择 **aifirst target → Signing & Capabilities**
2. 点击 **+ Capability** 搜索并添加：
   - **App Sandbox**
   - **Hardened Runtime**

### 7.2 App Sandbox 权限

| 权限 | 需要 | 原因 |
|---|---|---|
| Network (Outgoing) | ✅ | 连接 AI API（DeepSeek / Ollama / 自定义端点） |
| Network (Incoming) | ❌ | 不需要 |
| File Read | ❌ | 不需要 |
| File Write | ❌ | 不需要 |

### 7.3 Hardened Runtime

添加后不需要额外勾选例外（本项目不涉及音频输入、摄像头、JIT 等）。

### 7.4 关于 Entitlements 文件

项目已有 [`aifirst.entitlements`](file:///Users/guoxiujiang/Downloads/同步空间/porject/mac/aifirst/Sources/aifirst/aifirst.entitlements)，包含了初版配置。在 Xcode 中完成 Sandbox + Hardened Runtime 配置后，Xcode 会自动更新此文件。

> 每次修改 Capabilities 后，Xcode 都会更新 `.entitlements` 文件。建议将该文件纳入版本管理。

### 7.5 关于 Accessibility API 权限

App 使用 `AXIsProcessTrusted()` / `AXUIElementCopyAttributeValue` 获取用户选中文本，以及使用 `CGEvent` 模拟 Cmd+C。

**注意**：Accessibility 权限**不是 entitlement**，不需要在 Sandbox 中配置。它是在运行时的系统隐私设置中由用户授予的。

---

## 8. App Store Connect 配置

### 8.1 创建 App 记录

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 点击 **App → + 新建 App**

   | 字段 | 值 |
   |---|---|
   | **平台** | macOS |
   | **名称** | `AIFirst`（必须与 Xcode Target 名称一致） |
   | **语言** | 简体中文（首选项，后续可添加英文） |
   | **Bundle ID** | `com.guoxj.aifirst`（与 Xcode 项目一致） |
   | **SKU** | `aifirst_1_0_0`（唯一标识，按版本命名即可） |

### 8.2 填写 App 信息

| 项目 | 填写建议 |
|---|---|
| **描述（中文）** | AIFirst 是一款 macOS 菜单栏 AI 助手。支持多 API 配置（DeepSeek、Ollama 等）、AI 聊天、快捷操作（翻译/润色/总结/解释代码/扩写）。选中文本后一键处理，全局快捷键秒级响应，支持自定义 Prompt 动作。 |
| **描述（英文）** | AIFirst is a macOS menu bar AI assistant. Features: multi-API support (DeepSeek, Ollama, etc.), AI chat with streaming output, quick actions (translate/polish/summarize/explain code/expand), custom action prompts, global hotkeys, and multi-language support. |
| **关键词** | AI, 聊天, 翻译, 润色, 总结, 写作助手, macOS, ChatGPT, LLM, 快捷操作, AIFirst, 人工智能 |
| **技术支持 URL** | 推荐使用 GitHub 仓库地址：`https://github.com/你的用户名/aifirst` |
| **营销 URL** | 可选，不填 |
| **隐私政策 URL** | **必须** — 见第 12.3 节 |

### 8.3 准备截图

macOS App Store 需要 **至少 1 张**截图（推荐 3-5 张，显示不同功能）：

| 截图尺寸（任选一种） | 说明 |
|---|---|
| 1280×800 | 非 Retina 屏幕 |
| 1440×900 | 常见笔记本分辨率 |
| 2880×1800 | Retina（推荐，更清晰） |

**建议截图内容**：

1. **AI 聊天界面** — 显示与 AI 的对话，包含输入框和消息气泡
2. **快捷操作面板** — 显示选中文本后的操作界面（翻译/润色等按钮）
3. **设置窗口 — API 配置** — 显示多 API 配置列表（DeepSeek、Ollama）
4. **设置窗口 — 快捷键** — 显示快捷键设置界面
5. **自定义动作** — 显示用户自定义 Prompt 的界面

> 可以用模拟数据填充对话内容，看起来更丰富。确保截图语言与 App Store 语言版本对应。

### 8.4 定价与销售范围

| 项目 | 建议 |
|---|---|
| **价格** | 免费（Free） — 个人开发者前期积累用户 |
| **可用地区** | 全部（All territories） |

---

## 9. 构建与归档

### 9.1 配置版本号

1. Xcode 选择 **aifirst target → General**
2. **Version**（Marketing Version）：`1.0.0`
3. **Build**（Current Project Version）：`1`（每次提交递增）

### 9.2 选择编译架构

在 Xcode 顶部 Scheme 选择器中：
- 选择 **aifirst** scheme（不是 Any Mac）
- **Product → Destination → Any Mac（Apple Silicon，Intel）** 或直接使用 **My Mac**（取决于你的机器）

> 确保 Archive 时使用 **Any Mac**，这样构建产物会同时包含 Intel 和 Apple Silicon 的原生二进制。

### 9.3 清理构建

```bash
xcodebuild clean \
  -scheme aifirst \
  -configuration Release
```

### 9.4 Archive

**推荐方法：Xcode GUI**

1. 顶部 Scheme 选择 **aifirst**，Destination 选择 **Any Mac（Apple Silicon，Intel）**
2. **Product → Archive**

**命令行方法（备选）：**

```bash
xcodebuild archive \
  -scheme aifirst \
  -configuration Release \
  -archivePath ~/Desktop/AIFirst.xcarchive \
  -destination "generic/platform=macOS"
```

### 9.5 验证归档

Archive 完成后，Xcode Organizer 自动打开：

1. 选择刚刚生成的 Archive
2. 点击 **Validate App**
3. 选择 **App Store Connect** 作为验证目标
4. 检查是否通过签名、sandbox、API 验证

> 如果 Validate 报错，务必解决后再上传。常见问题：
> - **Missing required icon**：AppIcon 未设置 → 按第 5 节添加
> - **Sandbox not enabled**：未启用 App Sandbox → 按第 7 节配置
> - **Provisioning profile issue**：签名配置问题 → 检查 Signing & Capabilities

---

## 10. 上传到 App Store Connect

### 方法一：Xcode Organizer（推荐）

1. Archive 成功后 → **Distribute App**
2. 选择 **App Store Connect**
3. 选择 **Upload**
4. 确认 Team 和签名信息
5. 点击 **Upload**

### 方法二：Transporter（备用）

1. 从 Mac App Store 免费下载 **Transporter**
2. Archive 后选择 **Export App**（导出为 `.app` 或 `.pkg`）
3. 将导出的文件拖入 Transporter
4. 点击提交

### 方法三：命令行（CI 场景）

```bash
# 导出 .pkg
xcodebuild -exportArchive \
  -archivePath ~/Desktop/AIFirst.xcarchive \
  -exportPath ~/Desktop/AIFirst_export \
  -exportOptionsPlist exportOptions.plist \
  -allowProvisioningUpdates

# 上传（需要先在 Apple ID 中生成 App-Specific Password）
xcrun altool --upload-app \
  -f ~/Desktop/AIFirst_export/AIFirst.pkg \
  -t macOS \
  -u "你的AppleID@email.com" \
  -p "@keychain:AC_PASSWORD"
```

---

## 11. 提交审核

### 11.1 操作步骤

1. 上传成功后 → App Store Connect → App → **准备提交**
2. 选择刚刚上传的构建版本
3. 填写审核备注（见 11.2）
4. 点击 **提交审核**

### 11.2 审核备注模板

```text
This is a macOS menu bar AI assistant app.

Key Features:
1. AI Chat — free conversation with configurable LLM APIs (OpenAI-compatible)
2. Quick Actions — text processing: translate, polish, summarize, explain code, expand
3. Custom Actions — users can create their own action prompts
4. Global Hotkeys — Option+Space for chat, Option+Cmd+L for quick actions panel
5. Multi-language — English, Simplified Chinese, Traditional Chinese

Technical Notes for Review:

1. Accessibility API (AXIsProcessTrusted, AXUIElementCopyAttributeValue):
   - Used as the PRIMARY method to retrieve selected text from other apps
   - Only triggered on explicit user action (hotkey or menu click)
   - Never reads data automatically

2. CGEvent.postToPid (targeted keyboard event simulation):
   - Used ONLY as a FALLBACK when Accessibility API returns no text
   - Falls back to simulating Cmd+C via CGEvent.postToPid(targetPid) — targets the specific frontmost app process
   - This is needed because some apps (Chrome, Electron-based apps) do not expose AXSelectedText via Accessibility API
   - Uses postToPid ONLY (targeted per-process), NOT post(tap:) (global HID event tap)
   - Triggered only when the user explicitly presses a hotkey
   - Clipboard is compared before/after to avoid reading stale content

3. Carbon Hotkey API (InstallEventHandler, kEventHotKeyPressed):
   - Used to register global hotkeys (e.g., Option+Space)
   - This is the standard macOS API for global keyboard shortcuts

4. NSAppTransportSecurity (NSAllowsLocalNetworking + localhost exception):
   - The app allows users to configure custom API endpoints
   - Including local services (e.g., Ollama at http://localhost:11434)
   - Dynamic API endpoint configuration is a core feature
   - NOT using NSAllowsArbitraryLoads — only local networking is allowed

5. LSUIElement (LSUIElement = true):
   - The app runs as a menu bar agent (no Dock icon)
   - A full settings window is available for configuration
   - "Quit" option is available in the menu bar menu

6. API Keys:
   - User API keys (e.g., DeepSeek API key) are stored locally in UserDefaults
   - No data is sent to any server owned by the developer
   - All network requests go to user-configured endpoints only

7. Services Menu (NSServices in Info.plist):
   - The app integrates with macOS Services menu
   - Users can right-click text → Services → AI Translate/Polish/Summarize/Explain Code

No login required. No user data collected or uploaded. Privacy policy URL is provided.
```

### 11.3 审核周期

| 状态 | 预计时间 |
|---|---|
| **正在审核** | 通常 1-3 个工作日，个人开发者可能稍慢 |
| **被拒绝** | Apple 会发送拒绝原因邮件，修改后重新提交 |
| **通过** | App 自动上架（可在 App Store Connect 设置为手动发布） |

---

## 12. 审核注意事项（关键）

### 12.1 Accessibility API + CGEvent 说明（审核重点）

本项目使用双层文本获取策略：

**第一层（Primary）：Accessibility API**
- `AXUIElementCopyAttributeValue` 读取 `AXSelectedText`
- 适用于大部分原生 macOS App（TextEdit、Xcode、Safari 等）
- 无需额外权限（仅需 Accessibility 授权）

**第二层（Fallback）：CGEvent.postToPid**
- 当 Accessibility API 无法获取文本时（典型情况：Chrome 等基于 Chromium 的浏览器），通过 `CGEvent.postToPid(frontmostPID)` 定向向前台 App 发送 Cmd+C，然后从剪贴板读取
- **只使用 `postToPid`**（定向到特定进程），**不使用 `post(tap: .cghidEventTap)`**（全局 HID 注入）
- 剪贴板在前后做对比，只有内容确实变化时才使用，避免读到过期数据

**审核应对策略**：

- ✅ 审核备注中已详细解释用途和两层机制（见 11.2）
- ✅ App 不会自动获取文本 — 仅在用户按快捷键时触发
- ✅ 如果用户未授权 Accessibility + CGEvent 也失败，会显示授权提示

### 12.2 Carbon 事件处理

App 使用 Carbon Event API 注册全局热键：

```swift
// HotkeyManager.swift — InstallEventHandler, RegisterEventHotKey
```

- 这是 macOS 标准的全局快捷键方案，**不是私有 API**
- Apple 审核不会阻止 Carbon API 的使用
- 但如果审核人员发现快捷键与其他系统快捷键冲突，可能会要求优化

### 12.3 隐私政策（必须提供）

**个人开发者免费方案**：

1. 使用 [Privacy Policy Generator](https://www.privacypolicies.com/) 免费生成
2. 托管到 GitHub Pages：
   - 创建仓库 `privacy-policy`
   - 将生成的 HTML 推送到 `gh-pages` 分支
   - 访问 `https://你的用户名.github.io/privacy-policy`
3. 将 URL 填入 App Store Connect

**隐私政策必须包含以下说明**：

- App 将用户选中的文本发送到**用户自行配置的第三方 AI API**（如 DeepSeek、Ollama）
- App **不收集、不存储、不上传**任何用户数据到开发者服务器
- 用户配置的 API Key 仅存储在本地 UserDefaults
- App 不会在未经用户操作的情况下读取其他 App 的内容
- App 不会追踪用户行为或发送分析数据

### 12.4 API Key 存储方式（安全提示）

当前项目将 API Key 直接存储在 `UserDefaults`（明文）：

```swift
// AppSettings.swift — UserDefaults.standard.data(forKey: "api_configs")
```

**⚠️ 这虽然不影响审核通过**（Apple 不强制要求 Keychain），但存在安全风险：
- 其他进程可以读取当前 App 的 UserDefaults
- 建议未来版本迁移到 **Keychain**（使用 `SecItemAdd` / `SecItemCopyMatching`）

对于 1.0 版本，可以先提交，后续更新中改进。

### 12.5 个人开发者常见被拒原因

| 常见问题 | 本项目情况 | 应对方法 |
|---|---|---|
| **功能不完整** | ✅ 聊天 + 快捷操作 + 自定义动作 功能完整 | 确保所有功能在 Release 模式下可用 |
| **崩溃** | — | 发布前测试：聊天、快捷操作、切换 API、设置页面 |
| **UI 不符合 macOS 规范** | ✅ 使用 SwiftUI 原生组件 | 检查菜单栏图标、窗口大小和关闭行为 |
| **隐私政策缺失** | ⚠️ 必须提供 | 按 12.3 节准备 |
| **Accessibility API 滥用** | ✅ 仅在用户操作时调用 | 审核备注详细说明 |
| **CGEvent 跨进程按键** | ✅ 仅用 `postToPid`（定向到前端 App），未用 `post(tap:)`（全局 HID 注入） | 审核备注已解释设计取舍 |
| **截图与实际不符** | — | 确保截图与 App 实际界面一致 |
| **没有提供测试账号** | ✅ App 无需登录 | 审核备注中说明 "No login required" |
| **App 使用私有 API** | ✅ 本项目仅使用公开 API | Carbon API、Accessibility API、CGEvent 均为公开 API |

### 12.6 macOS 14+ 要求

项目最低版本为 macOS 14.0。注意：
- 如果在 macOS 14 以下系统测试，确保兼容性
- App Store 中会显示 "Requires macOS 14.0 or later"

---

## 13. 提审前自查清单

### 必备项

- [ ] Apple Developer Program 已激活（$99 已支付）
- [ ] Xcode 工程 (`aifirst.xcodeproj`) 存在，编译成功（`Cmd+B`）
- [ ] Archive 成功（Product → Archive）
- [ ] Validate 验证通过（无沙盒/签名/API 错误）
- [ ] Bundle ID 已注册（`com.guoxj.aifirst`）

### App Store Connect

- [ ] App 记录已创建
- [ ] 隐私政策 URL 已填写（**必须**）
- [ ] App 描述已填写（中英文）
- [ ] 关键词已填写
- [ ] 截图已上传（至少 1 张，推荐 3-5 张）
- [ ] 定价已设置（免费）
- [ ] 技术支持 URL 已填写

### Xcode 项目

- [ ] Asset Catalog (`Assets.xcassets`) 已创建
- [ ] App Icon 已设置（所有尺寸已填充）
- [ ] 版本号已设置（Version: `1.0.0`, Build: `1`）
- [ ] App Sandbox 已启用（Network Outgoing）
- [ ] Hardened Runtime 已启用
- [ ] Info.plist 已补充 CFBundleVersion / CFBundleShortVersionString
- [ ] `Automatically manage signing` 已勾选
- [ ] Team 已选择

### 功能测试（Release 模式）

- [ ] 菜单栏图标正常显示
- [ ] AI 聊天功能可用（输入 → 发送 → 流式输出）
- [ ] 快捷操作面板可用（快捷键打开）
- [ ] 多 API 配置切换正常
- [ ] 设置窗口所有 tab 正常
- [ ] 自定义动作增删改正常
- [ ] 多语言切换正常
- [ ] 全局快捷键注册/响应正常
- [ ] 无崩溃、无卡死

### 审核备注

- [ ] 审核备注已填写（按 11.2 节模板）
- [ ] Accessibility API 使用理由已说明
- [ ] CGEvent 使用理由已说明
- [ ] Carbon Hotkey API 说明
- [ ] NSAllowsLocalNetworking / 本地网络理由已说明

---

## 14. 版本更新流程

```
1. 更新 project.yml 中的 MARKETING_VERSION（如有需要）
   或在 Xcode Target → General 中修改 Version / Build
2. 确认无新增敏感 API 使用
3. Product → Archive
4. Organizer → Distribute App → Upload
5. App Store Connect → 选择新构建 → 提交审核
```

> **变更 project.yml 后**：运行 `xcodegen generate --project .` 重新生成工程文件。

---

## 15. 附录：完整速查流程

```
第1步: 注册 Apple Developer Program（$99/年）
       → https://developer.apple.com/programs/

第2步: 打开 Xcode 工程
       → open aifirst.xcodeproj

第3步: 配置签名
       → Target → Signing & Capabilities
       → 勾选 Automatically manage signing
       → Team: 选择个人 Team

第4步: 补充 Info.plist 字段
       → CFBundleName、CFBundleDisplayName、CFBundleVersion 等

第5步: 创建 Assets.xcassets 并添加 App Icon
       → File → New → File → Asset Catalog
       → 命名为 Assets，保存到 Sources/aifirst/

第6步: 添加 App Sandbox + Hardened Runtime
       → Target → Signing & Capabilities → + Capability
       → App Sandbox → Network (Outgoing)
       → Hardened Runtime

第7步: 配置 App Store Connect
       → App Store Connect → 新建 App
       → Bundle ID: com.guoxj.aifirst
       → 填写描述、关键词、截图、隐私政策 URL

第8步: 构建并 Archive
       → Product → Archive（Destination 选 Any Mac）

第9步: Validate → Distribute App → Upload

第10步: 提交审核
       → App Store Connect → 选择构建版本
       → 填写审核备注（见 11.2 节）
       → 提交
```

---

> **最后更新**：2026-05-31 — 基于 xcodegen 生成的 `aifirst.xcodeproj` 工程
>
> **相关文件**：
> - Xcode 工程: `aifirst.xcodeproj`
> - xcodegen 配置: `project.yml`
> - Entitlements: `Sources/aifirst/aifirst.entitlements`
> - Info.plist: `Sources/aifirst/Info.plist`
