// SettingsStore.swift
// ProseKit — UserDefaults-backed preferences.
//
// Persists user preferences across app launches. Uses @AppStorage-compatible keys.

import SwiftUI

@MainActor
class SettingsStore: ObservableObject {

    // MARK: - Keys

    private enum Keys {
        static let defaultMode = "defaultRewriteMode"
        static let launchAtLogin = "launchAtLogin"
        static let showDoneNotification = "showDoneNotification"
        static let modelID = "modelID"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    // MARK: - Published Properties

    /// The default rewrite mode selected by the user.
    @Published var defaultMode: RewriteMode {
        didSet { UserDefaults.standard.set(defaultMode.rawValue, forKey: Keys.defaultMode) }
    }

    /// Whether the app should launch at login.
    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    /// Whether to briefly show "Done" feedback after a successful rewrite.
    @Published var showDoneNotification: Bool {
        didSet { UserDefaults.standard.set(showDoneNotification, forKey: Keys.showDoneNotification) }
    }

    /// The HuggingFace model ID to use.
    @Published var modelID: String {
        didSet { UserDefaults.standard.set(modelID, forKey: Keys.modelID) }
    }

    /// Whether the user has completed the first-run onboarding.
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: - Initialization

    init() {
        let defaults = UserDefaults.standard

        // Load saved mode or default to grammar
        if let savedMode = defaults.string(forKey: Keys.defaultMode),
           let mode = RewriteMode(rawValue: savedMode) {
            self.defaultMode = mode
        } else {
            self.defaultMode = .grammar
        }

        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        // Default to showing done notification
        if defaults.object(forKey: Keys.showDoneNotification) == nil {
            self.showDoneNotification = true
        } else {
            self.showDoneNotification = defaults.bool(forKey: Keys.showDoneNotification)
        }

        // Default model
        self.modelID = defaults.string(forKey: Keys.modelID) ?? "mlx-community/Qwen3-8B-4bit"

        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }
}
