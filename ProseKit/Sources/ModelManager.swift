// ModelManager.swift
// ProseKit — Manages model lifecycle: download, load, status tracking.
//
// On first launch, downloads Qwen3-8B-4bit (~4.3 GB) from HuggingFace.
// Model is cached in ~/Library/Application Support/ProseKit/models/
// Subsequent launches load from cache instantly.
//
// The download uses mlx-swift-lm's built-in HuggingFace integration,
// which handles resumable downloads and caching automatically.

import Foundation

@MainActor
class ModelManager: ObservableObject {

    // MARK: - State

    @Published var downloadProgress: Double = 0
    @Published var statusMessage: String = "Ready"
    @Published var isLoaded = false

    /// The underlying rewrite engine (holds the loaded model).
    let engine = RewriteEngine()

    // MARK: - Model Info

    /// Default model: Qwen3-8B-4bit, validated at 2.65s avg latency, 0% failure rate.
    nonisolated static let defaultModelID = "mlx-community/Qwen3-8B-4bit"

    /// Estimated model size for UI display.
    static let estimatedModelSize = "~4.3 GB"

    // MARK: - Initialization

    /// Load the model. Downloads from HuggingFace on first call.
    /// Updates appState with progress during download.
    func initialize(modelID: String = defaultModelID, appState: AppState) async {
        NSLog("[ModelManager] initialize() called with modelID: \(modelID)")
        appState.modelStatus = .downloading(progress: 0)
        statusMessage = "Preparing model..."

        do {
            try await engine.loadModel(id: modelID) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    let pct = Int(progress * 100)
                    self?.statusMessage = progress < 1.0
                        ? "Downloading: \(pct)%"
                        : "Loading model into memory..."
                    NSLog("[ModelManager] Download progress: \(pct)%")

                    appState.modelStatus = progress < 1.0
                        ? .downloading(progress: progress)
                        : .loading
                }
            }

            isLoaded = true
            statusMessage = "Model ready"
            appState.modelStatus = .ready
            try? "Model loaded successfully!".write(toFile: "/tmp/prosekit-status.txt", atomically: true, encoding: .utf8)

        } catch {
            let errorMsg = "\(error)"
            NSLog("[ModelManager] ERROR: %@", errorMsg)
            try? errorMsg.write(toFile: "/tmp/prosekit-error.txt", atomically: true, encoding: .utf8)
            statusMessage = "Failed: \(error.localizedDescription)"
            appState.modelStatus = .error(error.localizedDescription)
        }
    }

    /// Unload the model to free memory.
    func unload(appState: AppState) {
        engine.unloadModel()
        isLoaded = false
        downloadProgress = 0
        statusMessage = "Model unloaded"
        appState.modelStatus = .notDownloaded
    }

    // MARK: - Model Cache Info

    /// Path where mlx-swift-lm caches downloaded models.
    /// Default: ~/.cache/huggingface/hub/ (same as Python HuggingFace library)
    static var cacheDirectory: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".cache/huggingface/hub")
    }

    /// Check if a model is already cached locally.
    static func isModelCached(id: String) -> Bool {
        // HuggingFace cache uses a specific directory structure
        let sanitizedID = id.replacingOccurrences(of: "/", with: "--")
        let modelDir = cacheDirectory.appendingPathComponent("models--\(sanitizedID)")
        return FileManager.default.fileExists(atPath: modelDir.path)
    }

    /// Get approximate size of cached model files.
    static func cachedModelSize(id: String) -> String? {
        let sanitizedID = id.replacingOccurrences(of: "/", with: "--")
        let modelDir = cacheDirectory.appendingPathComponent("models--\(sanitizedID)")

        guard FileManager.default.fileExists(atPath: modelDir.path) else { return nil }

        let size = directorySize(url: modelDir)
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private static func directorySize(url: URL) -> UInt64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url,
                                                       includingPropertiesForKeys: [.fileSizeKey],
                                                       options: [.skipsHiddenFiles]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}
