// ClipboardFallback.swift
// ProseKit — Last-resort fallback for apps where Accessibility write fails.
//
// Uses: ⌘A (select all) → ⌘C (copy) → transform → ⌘V (paste)
// Only used when TextFieldAgent.writeText() fails.

import Cocoa
import ApplicationServices

struct ClipboardFallback {

    /// Read text from the focused field via clipboard (⌘A → ⌘C → read clipboard).
    /// Saves and restores the user's original clipboard content.
    func readViaClipboard() -> String? {
        let savedClipboard = readClipboard()
        defer {
            // Restore original clipboard after a delay
            if let saved = savedClipboard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.writeClipboard(saved)
                }
            }
        }

        simulateKeyPress(keyCode: 0, flags: .maskCommand)   // ⌘A
        Thread.sleep(forTimeInterval: 0.2)
        simulateKeyPress(keyCode: 8, flags: .maskCommand)    // ⌘C
        Thread.sleep(forTimeInterval: 0.3)

        return readClipboard()
    }

    /// Write text to the focused field via clipboard (put on clipboard → ⌘A → ⌘V).
    /// Saves and restores the user's original clipboard content.
    func writeViaClipboard(_ text: String) {
        let savedClipboard = readClipboard()

        writeClipboard(text)
        Thread.sleep(forTimeInterval: 0.1)
        simulateKeyPress(keyCode: 0, flags: .maskCommand)   // ⌘A
        Thread.sleep(forTimeInterval: 0.1)
        simulateKeyPress(keyCode: 9, flags: .maskCommand)    // ⌘V
        Thread.sleep(forTimeInterval: 0.3)

        // Restore original clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let saved = savedClipboard {
                self.writeClipboard(saved)
            }
        }
    }

    // MARK: - Private

    private func simulateKeyPress(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func readClipboard() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    private func writeClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
