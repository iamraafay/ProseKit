#!/usr/bin/env swift
// ax_write_test.swift — Iteration 0 (v2, research-informed)
//
// Proves the full pipeline: READ text → TRANSFORM → WRITE BACK
// Uses uppercase as a placeholder transform (LLM goes here later).
//
// Tries TWO write methods:
//   1. AXValue (set the entire text field value)
//   2. Select-all + kAXSelectedTextAttribute (replace selected text)
//
// Usage:
//   swift ax_write_test.swift
//   Then click into a text field with some text within 5 seconds.

import Cocoa
import ApplicationServices

// MARK: - Helpers

func getAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return result == .success ? value : nil
}

func getRole(_ element: AXUIElement) -> String? {
    return getAttribute(element, kAXRoleAttribute as String) as? String
}

func getValue(_ element: AXUIElement) -> String? {
    return getAttribute(element, kAXValueAttribute as String) as? String
}

func getChildren(_ element: AXUIElement) -> [AXUIElement] {
    guard let children = getAttribute(element, kAXChildrenAttribute as String) else { return [] }
    return children as? [AXUIElement] ?? []
}

func isSettable(_ element: AXUIElement, attribute: String) -> Bool {
    var settable: DarwinBoolean = false
    let result = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
    return result == .success && settable.boolValue
}

func enableEnhancedUI(_ appElement: AXUIElement) {
    AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
    AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, true as CFTypeRef)
}

func findTextFields(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 8) -> [AXUIElement] {
    if depth > maxDepth { return [] }
    var results: [AXUIElement] = []
    let role = getRole(element) ?? ""
    if ["AXTextArea", "AXTextField", "AXComboBox", "AXWebArea"].contains(role) {
        results.append(element)
    }
    for child in getChildren(element) {
        results.append(contentsOf: findTextFields(child, depth: depth + 1, maxDepth: maxDepth))
    }
    return results
}

/// Find the best text element using all three methods
func findBestTextElement(systemWide: AXUIElement, appElement: AXUIElement, appName: String) -> AXUIElement? {
    // Method 1: System-wide focused element
    print("🔍 Finding text field...")
    if let el = getAttribute(systemWide, kAXFocusedUIElementAttribute as String) {
        let element = el as! AXUIElement
        if getValue(element) != nil {
            let role = getRole(element) ?? "?"
            print("   ✅ Found via system-wide focus (role: \(role))")
            return element
        }
    }

    // Method 2: App-level focused element
    if let el = getAttribute(appElement, kAXFocusedUIElementAttribute as String) {
        let element = el as! AXUIElement
        if getValue(element) != nil {
            let role = getRole(element) ?? "?"
            print("   ✅ Found via app focus (role: \(role))")
            return element
        }
    }

    // Method 3: Tree walk
    let textFields = findTextFields(appElement)
    if let first = textFields.first, getValue(first) != nil {
        let role = getRole(first) ?? "?"
        print("   ✅ Found via tree walk (role: \(role), \(textFields.count) total)")
        return first
    }

    return nil
}

// MARK: - Main

print("╔══════════════════════════════════════════╗")
print("║  ProseKit — Accessibility WRITE Test v2  ║")
print("╚══════════════════════════════════════════╝")
print()

let trusted = AXIsProcessTrusted()
if !trusted {
    print("❌ Accessibility permission not granted!")
    print("   System Settings → Privacy & Security → Accessibility → add Terminal")
    exit(1)
}
print("✅ Accessibility permission: granted")
print()

print("⏳ You have 5 seconds — click into a text field WITH SOME TEXT...")
print("   (The script will UPPERCASE your text to prove the write pipeline works)")
print()

for i in (1...5).reversed() {
    print("   \(i)...")
    Thread.sleep(forTimeInterval: 1.0)
}
print()

guard let frontApp = NSWorkspace.shared.frontmostApplication else {
    print("❌ Could not determine frontmost application")
    exit(1)
}

let appName = frontApp.localizedName ?? "Unknown"
let pid = frontApp.processIdentifier
print("📱 App: \(appName) (PID: \(pid))")
print()

let appElement = AXUIElementCreateApplication(pid)
enableEnhancedUI(appElement)
Thread.sleep(forTimeInterval: 0.1)

let systemWide = AXUIElementCreateSystemWide()

guard let textElement = findBestTextElement(systemWide: systemWide, appElement: appElement, appName: appName) else {
    print("❌ Could not find a text field with readable text in \(appName)")
    print("   Try the clipboard fallback: swift ax_clipboard_fallback.swift")
    exit(1)
}

guard let originalText = getValue(textElement), !originalText.isEmpty else {
    print("⚠️  Text field is empty — type something first, then try again")
    exit(1)
}

let role = getRole(textElement) ?? "?"
print()
print("📖 ORIGINAL TEXT (from \(role)):")
print("─────────────────────────────────────────")
print(originalText)
print("─────────────────────────────────────────")
print()

// Transform (uppercase as proof-of-concept — LLM goes here)
let transformedText = originalText.uppercased()

// ─────────────────────────────────────────
// WRITE METHOD 1: Set AXValue directly
// ─────────────────────────────────────────
print("✏️  Write Method 1: Setting AXValue directly...")
let valueSettable = isSettable(textElement, attribute: kAXValueAttribute as String)
print("   AXValue is settable: \(valueSettable)")

var writeSuccess = false

if valueSettable {
    let result = AXUIElementSetAttributeValue(textElement, kAXValueAttribute as CFString, transformedText as CFTypeRef)
    if result == .success {
        writeSuccess = true
        print("   ✅ AXValue write succeeded!")
    } else {
        print("   ❌ AXValue write failed (error: \(result.rawValue))")
    }
}

// ─────────────────────────────────────────
// WRITE METHOD 2: Select all + set kAXSelectedTextAttribute
// (This is how Grammarly and similar tools do it)
// ─────────────────────────────────────────
if !writeSuccess {
    print()
    print("✏️  Write Method 2: Select-all + kAXSelectedTextAttribute...")

    // First, get the full text length
    let textLength = originalText.count

    // Create a range covering all text (location: 0, length: textLength)
    var fullRange = CFRangeMake(0, textLength)
    let rangeValue = withUnsafePointer(to: &fullRange) { ptr in
        AXValueCreate(.cfRange, ptr)
    }

    if let rangeValue = rangeValue {
        // Set the selected range to cover all text
        let selectResult = AXUIElementSetAttributeValue(textElement, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        if selectResult == .success {
            print("   Selected all text (range 0..\(textLength))")

            // Now replace the selected text
            let replaceResult = AXUIElementSetAttributeValue(textElement, kAXSelectedTextAttribute as CFString, transformedText as CFTypeRef)
            if replaceResult == .success {
                writeSuccess = true
                print("   ✅ kAXSelectedTextAttribute write succeeded!")
            } else {
                print("   ❌ kAXSelectedTextAttribute write failed (error: \(replaceResult.rawValue))")
            }
        } else {
            print("   ❌ Could not set selected range (error: \(selectResult.rawValue))")
        }
    } else {
        print("   ❌ Could not create AXValue for range")
    }
}

print()
if writeSuccess {
    print("✅ WRITE SUCCESS!")
    print("─────────────────────────────────────────")
    print(transformedText)
    print("─────────────────────────────────────────")
    print()
    print("🎉 Full pipeline works in \(appName)!")
    print("   read → transform → write back")
    print()
    print("💡 Press ⌘Z in \(appName) to undo.")
} else {
    print("❌ Both write methods failed in \(appName)")
    print("   This app needs the clipboard fallback.")
    print("   Try: swift ax_clipboard_fallback.swift")
}

print()
print("Done.")
