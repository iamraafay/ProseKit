// HotkeyManager.swift
// ProseKit — Registers and manages global keyboard shortcuts.
//
// Primary hotkey: ⌘⇧G (triggers rewrite with current mode)
// Undo hotkey: ⌘⇧Z (restores original text)
//
// Uses NSEvent.addGlobalMonitorForEvents which requires Accessibility permission.
// The monitor observes key events from all apps without intercepting them.

import Cocoa

@MainActor
class HotkeyManager: ObservableObject {

    // MARK: - Callbacks

    /// Called when the rewrite hotkey (⌘⇧G) is pressed.
    var onRewriteTriggered: (() -> Void)?

    /// Called when the undo hotkey (⌘⇧Z) is pressed.
    var onUndoTriggered: (() -> Void)?

    // MARK: - State

    @Published var isRegistered = false

    private var globalMonitor: Any?
    private var localMonitor: Any?

    // MARK: - Registration

    /// Register global hotkey monitors. Requires Accessibility permission.
    func register() {
        guard globalMonitor == nil else { return }

        // Global monitor: catches events when OTHER apps are focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
        }

        // Local monitor: catches events when OUR menu bar is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyEvent(event)
            }
            return event // pass through — don't consume
        }

        isRegistered = true
    }

    /// Unregister all hotkey monitors.
    func unregister() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        isRegistered = false
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Use keyCode for reliability across keyboard layouts
        // keyCode 5 = G on all macOS keyboards
        let keyG: UInt16 = 5
        let keyZ: UInt16 = 6

        // ⌘⇧G → Rewrite
        if modifiers == [.command, .shift] && event.keyCode == keyG {
            onRewriteTriggered?()
            return
        }

        // ⌘⇧Z → Undo rewrite
        if modifiers == [.command, .shift] && event.keyCode == keyZ {
            onUndoTriggered?()
            return
        }
    }

    // MARK: - Cleanup

    deinit {
        // Note: Can't call unregister() in deinit because it's @MainActor
        // The monitors will be cleaned up when the app terminates anyway
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
    }
}
