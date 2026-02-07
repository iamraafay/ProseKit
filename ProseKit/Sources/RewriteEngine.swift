// RewriteEngine.swift
// ProseKit — LLM inference wrapper using Apple's mlx-swift-lm.
//
// Handles text rewriting by sending the user's text to a locally-running
// Qwen3-8B model with mode-specific system prompts.
//
// Key design decisions:
// - Each rewrite creates a fresh ChatSession (no context carry-over between rewrites)
// - System prompt includes `/no_think` to disable chain-of-thought (5.7x faster)
// - Temperature varies by mode: 0.3 for grammar, 0.7 for creative modes
// - Max tokens capped at 2048 to prevent runaway generation
//
// MARK: - XCODE AGENT
// If the mlx-swift-lm API has changed, the key methods to verify are:
// - loadModel(id:) — top-level function for loading by HuggingFace ID
// - ChatSession — conversation management with system prompt support
// - session.respond(to:) and session.streamResponse(to:) — inference methods

import Foundation
import MLXLLM
import MLXLMCommon

@MainActor
class RewriteEngine: ObservableObject {

    // MARK: - State

    @Published var isModelLoaded = false
    @Published var isProcessing = false

    /// The model container (holds weights + tokenizer).
    private var modelContainer: ModelContainer?

    // MARK: - Model Loading

    /// Load a model from HuggingFace. Downloads on first call, caches locally after that.
    ///
    /// - Parameters:
    ///   - id: HuggingFace model ID, e.g. "mlx-community/Qwen3-8B-4bit"
    ///   - onProgress: Called with download progress (0.0 to 1.0)
    func loadModel(id: String = "mlx-community/Qwen3-8B-4bit",
                   onProgress: @escaping (Double) -> Void) async throws {

        NSLog("[RewriteEngine] loadModel() called with id: \(id)")

        let configuration = ModelConfiguration(id: id)
        NSLog("[RewriteEngine] ModelConfiguration created, calling LLMModelFactory.shared.loadContainer...")

        modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration
        ) { progress in
            Task { @MainActor in
                onProgress(progress.fractionCompleted)
            }
        }

        NSLog("[RewriteEngine] Model container loaded successfully")
        isModelLoaded = true
    }

    // MARK: - Rewriting

    /// Rewrite text using the specified mode.
    ///
    /// Creates a fresh ChatSession per rewrite to avoid context contamination.
    /// Returns the rewritten text, or throws if generation fails.
    func rewrite(_ text: String, mode: RewriteMode) async throws -> String {
        guard let container = modelContainer else {
            throw RewriteError.modelNotLoaded
        }

        isProcessing = true
        defer { isProcessing = false }

        // Combine system prompt + user text into a single message.
        // ChatSession.respond(to:) doesn't take a separate system prompt parameter,
        // so we prepend the mode's system prompt (including /no_think) directly.
        let prompt = """
        \(mode.systemPrompt)

        \(text)
        """

        let session = ChatSession(container)
        let response = try await session.respond(to: prompt)

        // Clean up the response
        let cleaned = cleanResponse(response)

        guard !cleaned.isEmpty else {
            throw RewriteError.emptyResponse
        }

        return cleaned
    }

    /// Stream a rewrite token-by-token for real-time progress.
    /// Returns the full rewritten text after streaming completes.
    func rewriteStreaming(_ text: String, mode: RewriteMode,
                          onToken: @escaping (String) -> Void) async throws -> String {
        guard let container = modelContainer else {
            throw RewriteError.modelNotLoaded
        }

        isProcessing = true
        defer { isProcessing = false }

        let prompt = """
        \(mode.systemPrompt)

        \(text)
        """

        let session = ChatSession(container)
        var fullResponse = ""

        for try await token in session.streamResponse(to: prompt) {
            fullResponse += token
            onToken(token)
        }

        return cleanResponse(fullResponse)
    }

    // MARK: - Response Cleaning

    /// Clean up LLM response: strip quotes, think tags, extra whitespace.
    private func cleanResponse(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip any <think>...</think> blocks (safety net — /no_think should prevent these)
        if let regex = try? NSRegularExpression(pattern: "<think>.*?</think>",
                                                 options: .dotMatchesLineSeparators),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            text = text.replacingCharacters(in: range, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip wrapping quotes (the model sometimes wraps in quotes despite instructions)
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) ||
           (text.hasPrefix("'") && text.hasSuffix("'")) {
            text = String(text.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip markdown code blocks
        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: "\n")
            let filtered = lines.filter { !$0.hasPrefix("```") }
            text = filtered.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return text
    }

    // MARK: - Unload

    /// Unload the model to free memory.
    func unloadModel() {
        modelContainer = nil
        isModelLoaded = false
    }

    // MARK: - Errors

    enum RewriteError: LocalizedError {
        case modelNotLoaded
        case emptyResponse
        case generationFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:       return "Model is not loaded"
            case .emptyResponse:        return "Model returned empty response"
            case .generationFailed(let msg): return "Generation failed: \(msg)"
            }
        }
    }
}
