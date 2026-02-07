// TextFieldAgent.swift
// ProseKit — Reads and writes text fields in any macOS app via Accessibility API.
//
// Uses PID-based approach (proven reliable in Iteration 0 testing):
// - Messages (AXTextField): ✅ read ✅ write
// - Slack/Electron (AXTextArea): ✅ read ✅ write
// - Safari browser text fields (AXTextArea): ✅ read ✅ write
//
// The system-wide kAXFocusedUIElementAttribute method was tested and FAILED
// in all three apps. It has been removed from this production module.
//
// Key requirement: AXEnhancedUserInterface must be set on Chrome/Electron apps
// before reading their accessibility tree. We set it on every app (costs nothing
// on native apps, required for Electron).

import Cocoa
import ApplicationServices

struct TextFieldAgent {

    // MARK: - Public API

    /// Read text from the currently focused text field in the frontmost app.
    /// Returns the text and the AXUIElement (needed for writing back).
    /// Returns nil if no text field is focused or text can't be read.
    func readFocusedText() -> (text: String, element: AXUIElement)? {
        guard let (appElement, _) = getFrontmostApp() else { return nil }

        enableEnhancedUI(appElement)

        guard let textElement = getFocusedTextElement(appElement: appElement) else { return nil }
        guard let text = getValue(textElement) else { return nil }

        return (text, textElement)
    }

    /// Write text back to a text field element.
    /// Tries direct AXValue first (worked in all tested apps).
    /// Falls back to select-all + replace via kAXSelectedTextAttribute.
    /// Returns true if write succeeded.
    func writeText(_ newText: String, to element: AXUIElement, originalLength: Int) -> Bool {
        // Primary: direct AXValue set (worked in Messages, Slack, Safari)
        if isSettable(element, attribute: kAXValueAttribute as String) {
            let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFTypeRef)
            if result == .success { return true }
        }

        // Fallback: select-all + replace selected text
        return writeViaSelectedText(newText, to: element, selectLength: originalLength)
    }

    /// Check if the process has Accessibility permission.
    var hasAccessibilityPermission: Bool {
        return AXIsProcessTrusted()
    }

    /// Get the name of the frontmost app.
    var frontmostAppName: String? {
        return NSWorkspace.shared.frontmostApplication?.localizedName
    }

    // MARK: - Private: App & Element Discovery

    /// Get the frontmost app's AXUIElement via PID (the proven-reliable approach).
    private func getFrontmostApp() -> (AXUIElement, String)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let name = app.localizedName ?? "Unknown"
        return (AXUIElementCreateApplication(pid), name)
    }

    /// Get the focused text element from the frontmost app.
    /// Primary: app-level kAXFocusedUIElementAttribute (works in Messages, Slack, Safari).
    /// Fallback: recursive tree walk for AXTextArea/AXTextField elements.
    private func getFocusedTextElement(appElement: AXUIElement) -> AXUIElement? {
        // Primary: PID-based focused element (worked in all tested apps)
        if let el = getAttribute(appElement, kAXFocusedUIElementAttribute as String) {
            let element = el as! AXUIElement
            if getValue(element) != nil {
                return element
            }
        }

        // Fallback: walk the tree looking for text fields
        let textFields = findTextFields(appElement)
        if let first = textFields.first, getValue(first) != nil {
            return first
        }

        return nil
    }

    // MARK: - Private: Electron/Chrome Support

    /// Enable enhanced accessibility for Chrome/Electron apps.
    /// Costs nothing on native apps, required for Electron apps to expose their AX tree.
    private func enableEnhancedUI(_ appElement: AXUIElement) {
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, true as CFTypeRef)
    }

    // MARK: - Private: Write Fallback

    /// Write via select-all + replace selected text.
    /// Used when direct AXValue write isn't supported.
    private func writeViaSelectedText(_ newText: String, to element: AXUIElement, selectLength: Int) -> Bool {
        var fullRange = CFRangeMake(0, selectLength)
        guard let rangeValue = withUnsafePointer(to: &fullRange, { ptr in
            AXValueCreate(.cfRange, ptr)
        }) else { return false }

        let selectResult = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue)
        guard selectResult == .success else { return false }

        let replaceResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFTypeRef)
        return replaceResult == .success
    }

    // MARK: - Private: Tree Walk Fallback

    /// Recursively search for text field elements in the accessibility tree.
    /// Used as a last resort if focused element detection fails.
    private func findTextFields(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 8) -> [AXUIElement] {
        if depth > maxDepth { return [] }
        var results: [AXUIElement] = []
        let role = getRole(element) ?? ""
        if ["AXTextArea", "AXTextField", "AXComboBox"].contains(role) {
            results.append(element)
        }
        for child in getChildren(element) {
            results.append(contentsOf: findTextFields(child, depth: depth + 1, maxDepth: maxDepth))
        }
        return results
    }

    // MARK: - Private: AX Helpers

    private func getAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    private func getRole(_ element: AXUIElement) -> String? {
        return getAttribute(element, kAXRoleAttribute as String) as? String
    }

    private func getValue(_ element: AXUIElement) -> String? {
        return getAttribute(element, kAXValueAttribute as String) as? String
    }

    private func getChildren(_ element: AXUIElement) -> [AXUIElement] {
        guard let children = getAttribute(element, kAXChildrenAttribute as String) else { return [] }
        return children as? [AXUIElement] ?? []
    }

    private func isSettable(_ element: AXUIElement, attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        let result = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return result == .success && settable.boolValue
    }
}
