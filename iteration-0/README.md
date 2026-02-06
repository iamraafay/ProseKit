# Iteration 0 — Accessibility API Proof of Concept

The riskiest thing first: can we read and write text in other apps' text fields?

## Setup (one-time)

1. Open **System Settings → Privacy & Security → Accessibility**
2. Add your **Terminal app** (Terminal.app, iTerm2, or whatever you use)
3. Toggle it ON

Without this, none of the scripts will work.

## Test 1: Read

Proves we can read text from a focused text field in another app.

```bash
cd ~/Projects/GrammarlyReplacement/iteration-0
swift ax_read_test.swift
```

You get 3 seconds to click into a text field (Slack, Chrome, Notes, etc.) with some text in it. The script will print whatever text is in that field.

## Test 2: Write

Proves the full read → transform → write-back loop.

```bash
swift ax_write_test.swift
```

Same deal — 3 seconds to click into a text field. The script reads your text, UPPERCASES it, and writes it back into the field. Press ⌘Z to undo.

## Test 3: Clipboard Fallback

For apps where Accessibility write fails (usually Electron apps like Slack, Discord).

```bash
swift ax_clipboard_fallback.swift
```

Uses select-all → copy → transform → paste instead of direct AXValue manipulation.

## Test Matrix

Run each test in each app and fill this in:

| App | Read (Test 1) | Write (Test 2) | Clipboard Fallback (Test 3) | Notes |
|-----|:---:|:---:|:---:|-------|
| Notes | | | | |
| Safari (text input) | | | | |
| Chrome (text input) | | | | |
| Slack | | | | |
| Mail (compose) | | | | |
| VS Code | | | | |
| Discord | | | | |
| Messages | | | | |

Mark each cell: ✅ works, ❌ fails, ⚠️ partial

## What we're looking for

**Green light to proceed:** Read works in 5+ apps. Write OR clipboard fallback works in 5+ apps.

**Yellow light:** Read works in 4+ apps, but write is spotty. We lean heavily on clipboard fallback.

**Red light:** Read fails in most apps. We need to rethink the approach (maybe go browser-extension-only).

## Troubleshooting

**"Accessibility permission not granted"**
→ System Settings → Privacy & Security → Accessibility → make sure Terminal is listed AND toggled on. You may need to re-add it after macOS updates.

**Read works but Write fails**
→ Expected for some apps (especially Electron-based ones). That's what the clipboard fallback is for.

**Clipboard fallback pastes wrong content**
→ There may be a race condition. Try increasing the sleep durations in the script.

**"Could not find focused UI element"**
→ You may have clicked on a non-text element (like a button or label). Make sure your cursor is blinking in a text input.
