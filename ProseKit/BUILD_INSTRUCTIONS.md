# ProseKit — Xcode Project Setup

## What You're Building

A macOS menu bar app that rewrites text in any text field using a local LLM. No cloud, no accounts, no telemetry.

**Flow:** User types in any app → presses ⌘⇧G → text gets rewritten in place by Qwen3-8B running locally via Apple MLX.

## Architecture

```
⌘⇧G pressed (HotkeyManager)
        │
        ▼
RewriteCoordinator.rewrite(mode:)
        │
        ├─ 1. TextFieldAgent.readFocusedText()      ← Accessibility API
        ├─ 2. UndoBuffer.save(original)
        ├─ 3. RewriteEngine.rewrite(text, mode)      ← MLX local LLM
        └─ 4. TextFieldAgent.writeText(rewritten)    ← Accessibility API
                │
                └─ fallback: ClipboardFallback        ← ⌘A→⌘C→transform→⌘V
```

## Step 1: Create Xcode Project

1. Open Xcode 26.3
2. File → New → Project
3. Choose **macOS → App**
4. Settings:
   - Product Name: `ProseKit`
   - Organization Identifier: `com.prosekit`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck "Include Tests" (for now)
5. Save to `~/Projects/GrammarlyReplacement/`

## Step 2: Configure as Menu Bar App

In the project navigator, select the ProseKit target:

### Info.plist
Add these keys (via target → Info tab):
- `LSUIElement` = `YES` (hides dock icon, menu bar only)
- `NSAccessibilityUsageDescription` = `ProseKit needs accessibility access to read and rewrite text in other apps.`

### Signing & Capabilities
- **Remove** App Sandbox (ProseKit needs Accessibility API, which doesn't work in sandbox)
- **Add** "Outgoing Connections (Client)" if you keep sandbox, OR just remove sandbox entirely
- **Add** "Increased Memory Limit" entitlement (for the ~4.3GB model)

### Entitlements file (ProseKit.entitlements)
If you removed sandbox, your entitlements should look like:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

The `network.client` entitlement allows downloading the model from HuggingFace on first launch.

## Step 3: Add Swift Package Dependencies

In Xcode: File → Add Package Dependencies

### 1. mlx-swift-lm (Apple's MLX language model library)
- URL: `https://github.com/ml-explore/mlx-swift-lm`
- Branch: `main`
- Add product: `MLXLMCommon` to ProseKit target

### 2. swift-huggingface (optional, only if mlx-swift-lm doesn't handle downloads)
- URL: `https://github.com/huggingface/swift-huggingface`
- Branch: `main`
- Add product: `HuggingFaceHub` to ProseKit target

**Note:** `mlx-swift-lm` likely bundles HuggingFace download support already. Start without swift-huggingface and add it only if needed.

## Step 4: Add Source Files

Copy all `.swift` files from `ProseKit/Sources/` into the Xcode project's source group.

Delete the auto-generated `ContentView.swift` — we don't need it.

Replace the auto-generated `ProseKitApp.swift` with ours.

### Source Files (in dependency order):

| File | Purpose | Dependencies |
|------|---------|-------------|
| `RewriteMode.swift` | Mode enum + system prompts | None |
| `AppState.swift` | Published app state | RewriteMode |
| `SettingsStore.swift` | UserDefaults persistence | RewriteMode |
| `TextFieldAgent.swift` | Read/write text fields via AX API | Cocoa, ApplicationServices |
| `ClipboardFallback.swift` | ⌘A→⌘C→transform→⌘V backup | Cocoa |
| `UndoBuffer.swift` | Stores originals for undo | TextFieldAgent |
| `ModelManager.swift` | Downloads model from HuggingFace | MLXLMCommon |
| `RewriteEngine.swift` | LLM inference wrapper | MLXLMCommon, RewriteMode |
| `HotkeyManager.swift` | Global ⌘⇧G registration | Cocoa |
| `RewriteCoordinator.swift` | Orchestrates the pipeline | All above |
| `MenuBarView.swift` | SwiftUI menu bar dropdown | AppState, RewriteCoordinator |
| `ProseKitApp.swift` | App entry point | All above |

## Step 5: Build & Run

1. Build (⌘B) — resolve any package dependency issues first
2. Run (⌘R) — the app should appear as a menu bar icon
3. Grant Accessibility permission when prompted (System Settings → Privacy → Accessibility)
4. First launch will download Qwen3-8B (~4.3 GB) — wait for the progress indicator
5. Once model is loaded, press ⌘⇧G in any text field to rewrite

## Key Technical Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| LLM Framework | mlx-swift-lm (embedded) | Single binary, no external dependency |
| Model | Qwen3-8B-4bit | Best quality/speed balance, validated at 2.65s avg |
| Model delivery | First-launch download from HuggingFace | Keeps app small (~100MB vs 4.3GB) |
| Text field access | PID-based Accessibility API | Only method that worked reliably in testing |
| Write method | Direct AXValue set | Worked in Messages, Slack, Safari |
| Hotkey | ⌘⇧G global monitor | Rarely conflicts, easy to remember |
| Think mode | `/no_think` in system prompt | Eliminates chain-of-thought, 5.7x faster |
| Sandbox | Disabled | Required for Accessibility API |

## Validated Assumptions (from Iteration 0)

- ✅ PID-based AX read works in Messages, Slack, Safari
- ✅ Direct AXValue write works in all tested apps
- ✅ AXEnhancedUserInterface flag enables Electron/Chrome apps
- ✅ Qwen3-8B with `/no_think` rewrites in < 3s avg, 0% failure rate
- ✅ All four modes produce acceptable quality
- ✅ Proper nouns, URLs, @mentions preserved correctly

## Files to Adjust with Xcode Agent

If `mlx-swift-lm`'s API differs from what's in the source files, the key files to update are:
- `RewriteEngine.swift` — model loading and inference calls
- `ModelManager.swift` — download progress callbacks

Look for `// MARK: - XCODE AGENT` comments in these files for areas that may need API verification.
