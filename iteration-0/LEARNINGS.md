# Iteration 0 — Learnings

## Meta-Lesson

**Do the research before writing code.** Our first attempt used the wrong API approach (system-wide focused element) and failed on iMessages. 30 minutes of research revealed three alternative methods, the `AXEnhancedUserInterface` flag for Electron apps, and how Grammarly actually solves this. The second attempt worked on the first try.

## Test Results

| App | Read | Write | Element Role | Method That Worked |
|-----|:---:|:---:|-------------|-------------------|
| Messages (iMessages) | ✅ | ✅ | AXTextField | PID-based (Method 2) |
| Slack (Electron) | ✅ | ✅ | AXTextArea | PID-based (Method 2) |
| Safari (GitHub textarea) | ✅ | ✅ | AXTextArea | PID-based (Method 2) |

## What Works

**PID-based app element → kAXFocusedUIElementAttribute (Method 2)**
- `AXUIElementCreateApplication(pid)` where pid comes from `NSWorkspace.shared.frontmostApplication.processIdentifier`
- Then query `kAXFocusedUIElementAttribute` on that app element
- Works for native apps, Electron apps, and browser text fields
- This is the approach we should use in the real app

**Direct AXValue write**
- `AXUIElementSetAttributeValue(element, kAXValueAttribute, newText)`
- Worked in every app we tested
- Simpler than the kAXSelectedTextAttribute approach
- This is our primary write method

**AXEnhancedUserInterface flag**
- Must call `AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface", true)` on Chrome/Electron apps
- Without this, Electron apps don't expose their accessibility tree at all
- Also set `AXManualAccessibility` for good measure
- Should be called once when we detect the frontmost app, before reading

## What Doesn't Work

**System-wide kAXFocusedUIElementAttribute (Method 1)**
- `AXUIElementCreateSystemWide()` → `kAXFocusedUIElementAttribute`
- Failed in ALL three apps tested (Messages, Slack, Safari)
- **Remove from production code** — it's dead weight

## What Works But We Don't Need (Yet)

**Recursive tree walk (Method 3)**
- Walking `kAXChildrenAttribute` recursively to find AXTextArea/AXTextField elements
- Works for Messages (found 2 fields), partially works for Slack (found AXWebArea but not the focused input)
- Useful as a last-resort fallback, but Method 2 was sufficient everywhere
- **Keep as fallback** but don't rely on it

**kAXSelectedTextAttribute write (Write Method 2)**
- Select-all via `kAXSelectedTextRangeAttribute` → replace via `kAXSelectedTextAttribute`
- Never needed since direct AXValue write worked everywhere
- **Keep as fallback** for apps where AXValue isn't settable

**Clipboard fallback (⌘A → ⌘C → transform → ⌘V)**
- Never tested because Accessibility write worked in all apps
- **Keep the code** — we'll need it for edge cases (VS Code, Discord, etc.)

## Architecture Decision: Minimal Viable Pipeline

Based on testing, the production pipeline should be:

```
1. Get frontmost app PID
2. Create AXUIElement for app
3. Set AXEnhancedUserInterface (always, costs nothing)
4. Get focused element via kAXFocusedUIElementAttribute
5. Read AXValue
6. Transform (LLM rewrite)
7. Set AXValue
8. If step 7 fails → try kAXSelectedTextAttribute
9. If step 8 fails → clipboard fallback
```

Steps 4-7 are the hot path. Steps 8-9 are fallbacks we may never hit.

## Key Technical Details

- Messages exposes text input as `AXTextField`, Slack/Safari use `AXTextArea` — code must handle both
- Slack's AXTextArea has `ChromeAXNodeId` attribute, confirming Chromium/Electron
- `AXIsProcessTrusted()` correctly detects whether Terminal has Accessibility permission
- The app will need to be distributed outside the Mac App Store (sandboxing conflicts with Accessibility API)
- Strings > 2040 characters can crash `AXUIElementSetAttributeValue` — need to handle this in production
