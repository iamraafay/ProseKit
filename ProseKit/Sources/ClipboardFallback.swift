// ClipboardFallback.swift
// ProseKit — Last-resort text replacement using the clipboard.
//
// When TextFieldAgent.writeText() fails (some apps don't support AXValue writes),
// this module uses simulated keystrokes: ⌘A (select all) → ⌘V (paste new text).
//
// The original clipboard content is saved and restored after the operation.
// This approach is less precise (replaces ALL text, not just the focused field's content)
// but works in virtually any app that supports paste.

import Cocoa

struct ClipboardFallback {

    // MARK: - Public API

    /// Replace the text in the currently focused text field using the clipboard.
    /// Saves and restores the clipboard contents.
    func writeViaClipboard(_ newText: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> (String, Data)? in
            guard let type = item.types.first,
                  let data = item.data(forType: type) else { return nil }
            return (type.rawValue, data)
        } ?? []

        // Set new text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        // Small delay to ensure clipboard is updated
        usleep(50_000) // 50ms

        // ⌘A (select all)
        simulateKeyPress(keyCode: 0, modifiers: .maskCommand) // 0 = A

        usleep(50_000) // 50ms

        // ⌘V (paste)
        simulateKeyPress(keyCode: 9, modifiers: .maskCommand) // 9 = V

        // Wait for paste to complete, then restore clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.restoreClipboard(pasteboard: pasteboard, items: savedItems)
        }
    }

    // MARK: - Private: Keyboard Simulation

    /// Simulate a key press using CGEvent.
    private func simulateKeyPress(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = modifiers
            keyDown.post(tap: .cghidEventTap)
        }

        usleep(10_000) // 10ms between down and up

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = modifiers
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Restore the clipboard to its previous state.
    private func restoreClipboard(pasteboard: NSPasteboard, items: [(String, Data)]) {
        pasteboard.clearContents()
        for (typeString, data) in items {
            let type = NSPasteboard.PasteboardType(typeString)
            pasteboard.setData(data, forType: type)
        }
    }
}
