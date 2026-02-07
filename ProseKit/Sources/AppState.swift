// AppState.swift
// ProseKit — Central observable state for the entire app.
//
// Published properties drive the SwiftUI menu bar UI reactively.
// All state mutations happen on @MainActor to keep UI updates safe.

import SwiftUI

@MainActor
class AppState: ObservableObject {

    // MARK: - Model Status

    enum ModelStatus: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case loading
        case ready
        case error(String)

        var displayText: String {
            switch self {
            case .notDownloaded:            return "Model not downloaded"
            case .downloading(let p):       return "Downloading model: \(Int(p * 100))%"
            case .loading:                  return "Loading model..."
            case .ready:                    return "Ready"
            case .error(let msg):           return "Error: \(msg)"
            }
        }
    }

    // MARK: - Processing Status

    enum ProcessingStatus: Equatable {
        case idle
        case reading
        case rewriting
        case writing
        case done
        case error(String)

        var displayText: String {
            switch self {
            case .idle:             return ""
            case .reading:          return "Reading text..."
            case .rewriting:        return "Rewriting..."
            case .writing:          return "Updating text field..."
            case .done:             return "Done!"
            case .error(let msg):   return "Error: \(msg)"
            }
        }

        var isActive: Bool {
            switch self {
            case .reading, .rewriting, .writing: return true
            default: return false
            }
        }
    }

    // MARK: - Published State

    /// Currently selected rewrite mode.
    @Published var currentMode: RewriteMode = .grammar

    /// Model download/loading status.
    @Published var modelStatus: ModelStatus = .notDownloaded

    /// Current processing pipeline status.
    @Published var processingStatus: ProcessingStatus = .idle

    /// Time taken for the last rewrite (seconds).
    @Published var lastRewriteTime: TimeInterval = 0

    /// Whether accessibility permission has been granted.
    /// Defaults to true because AXIsProcessTrusted() is unreliable during Xcode
    /// debug sessions. The rewrite pipeline handles the real failure gracefully
    /// (readFocusedText returns nil → "No text field found" error).
    @Published var hasAccessibilityPermission: Bool = true

    /// Number of rewrites performed this session.
    @Published var rewriteCount: Int = 0

    // MARK: - Computed Properties

    /// App is ready to rewrite (model loaded).
    /// Note: We don't require hasAccessibilityPermission here because
    /// AXIsProcessTrusted() returns false during Xcode debug sessions
    /// even when accessibility actually works. The pipeline handles
    /// the real failure case (readFocusedText returns nil).
    var isReady: Bool {
        if case .ready = modelStatus { return true }
        return false
    }

    /// A rewrite is currently in progress.
    var isProcessing: Bool {
        processingStatus.isActive
    }

    /// Menu bar icon name based on current state.
    var menuBarIcon: String {
        if isProcessing { return "arrow.triangle.2.circlepath" }
        if case .downloading = modelStatus { return "arrow.down.circle" }
        if case .loading = modelStatus { return "gear" }
        if case .error = modelStatus { return "exclamationmark.triangle" }
        if !hasAccessibilityPermission { return "lock" }
        return currentMode.sfSymbol
    }
}
