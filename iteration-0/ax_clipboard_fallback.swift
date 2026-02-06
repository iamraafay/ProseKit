#!/usr/bin/env swift
// ax_clipboard_fallback.swift
// Iteration 0: Clipboard-based fallback for apps where Accessibility write fails.
//
// Strategy:
//   1. Simulate ⌘A (select all) in the focused text field
//   2. Simulate ⌘C (copy) to get text onto clipboard
//   3. Read from clipboard
//   4. Transform the text (uppercase as proof-of-concept)
//   5. Put transformed text on clipboard
//   6. Simulate ⌘V (paste) to replace the text
//
// This is the fallback for Electron apps (Slack, VS Code, Discord) and any app
// where AXUIElementSetAttributeValue doesn't work.
//
// Usage:
//   1. Run: swift ax_clipboard_fallback.swift
//   2. You have 3 seconds — click into a text field with some text
//   3. Script will select-all, copy, transform, paste

import Cocoa
import ApplicationServices
import Carbon

// MARK: - Keyboard Simulation

func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags = []) {
    let source = CGEventSource(stateID: .hidSystemState)

    guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        print("❌ Failed to create keyboard event")
        return
    }

    keyDown.flags = flags
    keyUp.flags = flags

    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
}

func simulateCommandA() {
    // ⌘A — select all
    // Key code 0 = 'A'
    simulateKeyPress(keyCode: 0, flags: .maskCommand)
}

func simulateCommandC() {
    // ⌘C — copy
    // Key code 8 = 'C'
    simulateKeyPress(keyCode: 8, flags: .maskCommand)
}

func simulateCommandV() {
    // ⌘V — paste
    // Key code 9 = 'V'
    simulateKeyPress(keyCode: 9, flags: .maskCommand)
}

// MARK: - Clipboard

func readClipboard() -> String? {
    let pasteboard = NSPasteboard.general
    return pasteboard.string(forType: .string)
}

func writeClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

func getFocusedAppName() -> String {
    if let app = NSWorkspace.shared.frontmostApplication {
        return app.localizedName ?? app.bundleIdentifier ?? "Unknown"
    }
    return "Unknown"
}

// MARK: - Main

print("╔══════════════════════════════════════════╗")
print("║  ProseKit — Clipboard Fallback Test      ║")
print("╚══════════════════════════════════════════╝")
print()
print("⏳ You have 5 seconds — click into a text field WITH SOME TEXT...")
print("   (The script will select all → copy → UPPERCASE → paste)")
print()

// Save current clipboard content so we can restore it
let savedClipboard = readClipboard()

for i in (1...5).reversed() {
    print("   \(i)...")
    Thread.sleep(forTimeInterval: 1.0)
}
print()

let appName = getFocusedAppName()
print("📱 Active app: \(appName)")
print()

// Step 1: Select All
print("1️⃣  Simulating ⌘A (select all)...")
simulateCommandA()
Thread.sleep(forTimeInterval: 0.2) // Brief pause for the app to process

// Step 2: Copy
print("2️⃣  Simulating ⌘C (copy)...")
simulateCommandC()
Thread.sleep(forTimeInterval: 0.3) // Slightly longer pause for clipboard to update

// Step 3: Read from clipboard
guard let originalText = readClipboard(), !originalText.isEmpty else {
    print("❌ Clipboard is empty after ⌘A + ⌘C")
    print("   Make sure you clicked into a text field with text before the timer ran out")
    // Restore clipboard
    if let saved = savedClipboard { writeClipboard(saved) }
    exit(1)
}

print()
print("📖 ORIGINAL TEXT (from clipboard):")
print("─────────────────────────────────────────")
print(originalText.count > 500 ? String(originalText.prefix(500)) + "..." : originalText)
print("─────────────────────────────────────────")
print()

// Step 4: Transform
let transformedText = originalText.uppercased()

// Step 5: Put transformed text on clipboard
print("3️⃣  Putting transformed text on clipboard...")
writeClipboard(transformedText)
Thread.sleep(forTimeInterval: 0.1)

// Step 6: Paste
print("4️⃣  Simulating ⌘V (paste)...")
simulateCommandV()
Thread.sleep(forTimeInterval: 0.3)

print()
print("✅ CLIPBOARD FALLBACK COMPLETE!")
print("─────────────────────────────────────────")
print(transformedText.count > 500 ? String(transformedText.prefix(500)) + "..." : transformedText)
print("─────────────────────────────────────────")
print()
print("🎉 Clipboard pipeline works in \(appName)!")
print("   select-all → copy → transform → paste")
print()
print("💡 You can ⌘Z in \(appName) to undo the change.")

// Restore original clipboard content after a brief delay
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    if let saved = savedClipboard {
        writeClipboard(saved)
        print("📋 Original clipboard content restored.")
    }
}

// Keep run loop alive briefly to allow the clipboard restore
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.5))

print()
print("Done.")
