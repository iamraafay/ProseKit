// UndoBuffer.swift
// ProseKit — Stores original text before rewrites so users can undo.
//
// Since AXUIElementSetAttributeValue doesn't register with the app's native undo stack,
// we maintain our own buffer. When undo is triggered, we write the original text back
// to the same (or currently focused) text field.

import Cocoa
import ApplicationServices

/// A snapshot of text before it was rewritten.
struct UndoEntry {
    let originalText: String
    let element: AXUIElement
    let appName: String
    let timestamp: Date
}

class UndoBuffer {

    private var entries: [UndoEntry] = []
    private let maxEntries = 20

    // MARK: - Public API

    /// Save the original text before a rewrite. Call this BEFORE writing the rewritten text.
    func save(originalText: String, element: AXUIElement, appName: String = "Unknown") {
        let entry = UndoEntry(
            originalText: originalText,
            element: element,
            appName: appName,
            timestamp: Date()
        )
        entries.append(entry)

        // Trim old entries
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    /// Undo the most recent rewrite by writing the original text back.
    /// First tries the stored AXUIElement. If that's stale (user switched apps/fields),
    /// falls back to finding the currently focused text field.
    /// Returns true if undo succeeded.
    func undo() -> Bool {
        guard let entry = entries.popLast() else { return false }

        let agent = TextFieldAgent()

        // Try writing to the original element first
        if agent.writeText(entry.originalText, to: entry.element, originalLength: entry.originalText.count) {
            return true
        }

        // Original element might be stale — try the currently focused text field
        if let (_, currentElement) = agent.readFocusedText() {
            return agent.writeText(entry.originalText, to: currentElement, originalLength: entry.originalText.count)
        }

        // Both failed — put the entry back so user can try again
        entries.append(entry)
        return false
    }

    /// Whether there are any entries to undo.
    var canUndo: Bool {
        !entries.isEmpty
    }

    /// Peek at the most recent entry without removing it.
    var lastEntry: UndoEntry? {
        entries.last
    }

    /// Number of undo entries available.
    var count: Int {
        entries.count
    }

    /// Clear all undo history.
    func clear() {
        entries.removeAll()
    }
}
