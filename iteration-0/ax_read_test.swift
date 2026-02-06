#!/usr/bin/env swift
// ax_read_test.swift — Iteration 0 (v2, research-informed)
//
// Proves we can READ text from the focused text field in any app.
// Uses THREE methods to find the focused element (some apps like iMessages
// don't report focus via the standard system-wide query).
//
// Usage:
//   swift ax_read_test.swift
//   Then click into a text field within 5 seconds.
//
// Requires: Accessibility permission for Terminal
//   System Settings → Privacy & Security → Accessibility → add Terminal

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

func getTitle(_ element: AXUIElement) -> String? {
    return getAttribute(element, kAXTitleAttribute as String) as? String
}

func getSubrole(_ element: AXUIElement) -> String? {
    return getAttribute(element, kAXSubroleAttribute as String) as? String
}

func getRoleDescription(_ element: AXUIElement) -> String? {
    return getAttribute(element, kAXRoleDescriptionAttribute as String) as? String
}

func getAttributeNames(_ element: AXUIElement) -> [String] {
    var names: CFArray?
    AXUIElementCopyAttributeNames(element, &names)
    return (names as? [String]) ?? []
}

func getChildren(_ element: AXUIElement) -> [AXUIElement] {
    guard let children = getAttribute(element, kAXChildrenAttribute as String) else { return [] }
    return children as? [AXUIElement] ?? []
}

/// Enable enhanced accessibility for Chrome/Electron apps
func enableEnhancedUI(_ appElement: AXUIElement) {
    AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
    AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, true as CFTypeRef)
}

/// Recursively search the AX tree for text fields (AXTextArea, AXTextField, AXWebArea)
func findTextFields(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 8) -> [AXUIElement] {
    if depth > maxDepth { return [] }

    var results: [AXUIElement] = []
    let role = getRole(element) ?? ""

    // These are the roles that typically hold editable text
    let textRoles = ["AXTextArea", "AXTextField", "AXComboBox", "AXWebArea"]
    if textRoles.contains(role) {
        results.append(element)
    }

    for child in getChildren(element) {
        results.append(contentsOf: findTextFields(child, depth: depth + 1, maxDepth: maxDepth))
    }

    return results
}

func printElementInfo(_ element: AXUIElement, label: String) {
    let role = getRole(element) ?? "?"
    let subrole = getSubrole(element) ?? "-"
    let roleDesc = getRoleDescription(element) ?? "-"
    let value = getValue(element)
    let attrs = getAttributeNames(element)

    print("   \(label)")
    print("   Role: \(role) | Subrole: \(subrole) | Description: \(roleDesc)")
    print("   Has AXValue: \(value != nil) | Value length: \(value?.count ?? 0)")
    print("   Attributes: \(attrs.joined(separator: ", "))")
}

// MARK: - Main

print("╔══════════════════════════════════════════╗")
print("║  ProseKit — Accessibility READ Test v2   ║")
print("╚══════════════════════════════════════════╝")
print()

// Check permission FIRST
let trusted = AXIsProcessTrusted()
if !trusted {
    print("❌ Accessibility permission not granted!")
    print()
    print("   Fix: System Settings → Privacy & Security → Accessibility")
    print("   Add Terminal (or iTerm2, etc.) and toggle it ON")
    print()
    print("   If you already added it, try removing and re-adding it.")
    exit(1)
}
print("✅ Accessibility permission: granted")
print()

print("⏳ You have 5 seconds — click into a text field in another app...")
print("   (Make sure the cursor is BLINKING in the field)")
print()

for i in (1...5).reversed() {
    print("   \(i)...")
    Thread.sleep(forTimeInterval: 1.0)
}
print()

// Get frontmost app info
guard let frontApp = NSWorkspace.shared.frontmostApplication else {
    print("❌ Could not determine frontmost application")
    exit(1)
}

let appName = frontApp.localizedName ?? "Unknown"
let pid = frontApp.processIdentifier
print("📱 Frontmost app: \(appName) (PID: \(pid))")
print()

// Create app-level AXUIElement from PID (more reliable than system-wide for some apps)
let appElement = AXUIElementCreateApplication(pid)

// Enable enhanced UI for Chrome/Electron apps
enableEnhancedUI(appElement)

// Brief pause to let enhanced UI take effect
Thread.sleep(forTimeInterval: 0.1)

// ─────────────────────────────────────────
// METHOD 1: System-wide focused element
// ─────────────────────────────────────────
print("🔍 Method 1: System-wide kAXFocusedUIElementAttribute")
let systemWide = AXUIElementCreateSystemWide()
var method1Element: AXUIElement?

if let el = getAttribute(systemWide, kAXFocusedUIElementAttribute as String) {
    method1Element = (el as! AXUIElement)
    printElementInfo(method1Element!, label: "Found via system-wide")
} else {
    print("   ❌ System-wide returned no focused element")
}
print()

// ─────────────────────────────────────────
// METHOD 2: App → focused element (two-step)
// ─────────────────────────────────────────
print("🔍 Method 2: App (PID \(pid)) → kAXFocusedUIElementAttribute")
var method2Element: AXUIElement?

if let el = getAttribute(appElement, kAXFocusedUIElementAttribute as String) {
    method2Element = (el as! AXUIElement)
    printElementInfo(method2Element!, label: "Found via app element")
} else {
    print("   ❌ App element returned no focused UI element")
}
print()

// ─────────────────────────────────────────
// METHOD 3: Walk the AX tree to find text fields
// ─────────────────────────────────────────
print("🔍 Method 3: Recursive tree walk (looking for text fields)")
let textFields = findTextFields(appElement)
print("   Found \(textFields.count) text field(s) in \(appName)'s AX tree")
for (i, tf) in textFields.prefix(5).enumerated() {
    let role = getRole(tf) ?? "?"
    let value = getValue(tf)
    let valuePreview = value.map { $0.prefix(80) + ($0.count > 80 ? "..." : "") } ?? "(no value)"
    print("   [\(i)] \(role): \"\(valuePreview)\"")
}
print()

// ─────────────────────────────────────────
// Pick the best result
// ─────────────────────────────────────────
print("═══════════════════════════════════════════")
print()

// Priority: method 1 or 2 (direct focus), then method 3 (tree walk)
let focusedElement: AXUIElement? = method1Element ?? method2Element
var readText: String? = nil

if let focused = focusedElement {
    readText = getValue(focused)
}

// If direct focus didn't yield text, try the first text field from tree walk
if readText == nil, let firstTextField = textFields.first {
    readText = getValue(firstTextField)
    if readText != nil {
        print("ℹ️  Direct focus query failed, but found text via tree walk")
        print()
    }
}

if let text = readText {
    print("✅ READ SUCCESS!")
    print("─────────────────────────────────────────")
    if text.isEmpty {
        print("   (text field is empty — type something and try again)")
    } else {
        let display = text.count > 500 ? String(text.prefix(500)) + "... (\(text.count) chars total)" : text
        print(display)
    }
    print("─────────────────────────────────────────")
    print()
    print("📊 Stats:")
    print("   Characters: \(text.count)")
    print("   Words: \(text.split(separator: " ").count)")
    print("   App: \(appName)")
} else {
    print("❌ Could not read text from \(appName)")
    print()
    print("   All three methods failed:")
    print("   • Method 1 (system-wide focus): \(method1Element != nil ? "element found but no AXValue" : "no element")")
    print("   • Method 2 (app focus):         \(method2Element != nil ? "element found but no AXValue" : "no element")")
    print("   • Method 3 (tree walk):         \(textFields.count) text fields found, none had readable values")
    print()
    print("   This app may need the clipboard fallback.")
    print("   Try: swift ax_clipboard_fallback.swift")
}

print()
print("Done.")
