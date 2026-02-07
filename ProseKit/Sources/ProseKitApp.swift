// ProseKitApp.swift
// ProseKit — macOS menu bar app that rewrites text using a local LLM.
//
// Entry point for the app. Sets up:
// 1. Menu bar UI (via MenuBarExtra)
// 2. Global hotkey registration (⌘⇧G for rewrite, ⌘⇧Z for undo)
// 3. Model download/loading on first launch
// 4. Accessibility permission checking
//
// Requires:
// - Info.plist: LSUIElement = YES (hides dock icon)
// - Info.plist: NSAccessibilityUsageDescription (for Accessibility permission prompt)
// - Entitlements: com.apple.security.network.client (for HuggingFace download)
// - App Sandbox: DISABLED (Accessibility API doesn't work in sandbox)

import SwiftUI
import ApplicationServices

// MARK: - Shared State

/// Shared instances so both the App struct and AppDelegate can access them.
@MainActor
enum Shared {
    static let appState = AppState()
    static let modelManager = ModelManager()
    static let coordinator = RewriteCoordinator()
    static let settingsStore = SettingsStore()
    static let hotkeyManager = HotkeyManager()
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await setup()
        }
    }

    @MainActor
    private func setup() async {
        let appState = Shared.appState
        let modelManager = Shared.modelManager
        let coordinator = Shared.coordinator
        let settingsStore = Shared.settingsStore
        let hotkeyManager = Shared.hotkeyManager

        // 1. Load saved settings
        appState.currentMode = settingsStore.defaultMode

        // 2. Request accessibility permission if needed
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            // Wait for user to grant in System Settings
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        // 3. Register global hotkeys
        hotkeyManager.onRewriteTriggered = { [weak coordinator, weak appState] in
            guard let coordinator = coordinator, let appState = appState else { return }
            Task { @MainActor in
                await coordinator.rewrite(mode: appState.currentMode, appState: appState)
            }
        }

        hotkeyManager.onUndoTriggered = { [weak coordinator, weak appState] in
            guard let coordinator = coordinator, let appState = appState else { return }
            Task { @MainActor in
                coordinator.undo(appState: appState)
            }
        }

        hotkeyManager.register()

        // 4. Wire the rewrite engine to the coordinator
        coordinator.engine = modelManager.engine

        // 5. Download and load the model
        await modelManager.initialize(
            modelID: settingsStore.modelID,
            appState: appState
        )
    }
}

// MARK: - App Entry Point

@main
struct ProseKitApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(Shared.appState)
                .environmentObject(Shared.coordinator)
                .environmentObject(Shared.modelManager)
                .environmentObject(Shared.settingsStore)
        } label: {
            Image(systemName: Shared.appState.menuBarIcon)
        }
    }
}
