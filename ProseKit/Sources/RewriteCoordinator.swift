// RewriteCoordinator.swift
// ProseKit — Orchestrates the full rewrite pipeline.
//
// Pipeline: ⌘⇧G → read text → save undo → LLM rewrite → write back
//
// This is the "glue" module that connects:
// - TextFieldAgent (Accessibility API read/write)
// - RewriteEngine (LLM inference)
// - UndoBuffer (original text storage)
// - ClipboardFallback (last resort write method)
// - AppState (UI state updates)

import Foundation

@MainActor
class RewriteCoordinator: ObservableObject {

    // MARK: - Dependencies

    let textFieldAgent = TextFieldAgent()
    let undoBuffer = UndoBuffer()

    /// Set by the app on launch after model is loaded.
    var engine: RewriteEngine?

    // MARK: - Pipeline

    /// Execute the full rewrite pipeline.
    ///
    /// 1. Read focused text field (Accessibility API)
    /// 2. Save original to undo buffer
    /// 3. Send to LLM for rewriting
    /// 4. Write rewritten text back to the text field
    /// 5. Fall back to clipboard if write fails
    func rewrite(mode: RewriteMode, appState: AppState) async {
        guard let engine = engine else {
            appState.processingStatus = .error("Model not loaded")
            resetAfterDelay(appState: appState)
            return
        }

        guard !appState.isProcessing else {
            return // Already processing — ignore duplicate triggers
        }

        // ── Step 1: Read ─────────────────────────────────────────
        // Note: We don't gate on AXIsProcessTrusted() because it returns false
        // during Xcode debug sessions even when accessibility works fine.
        // If accessibility isn't available, readFocusedText() returns nil
        // and we handle it below.

        appState.processingStatus = .reading

        guard let (text, element) = textFieldAgent.readFocusedText() else {
            appState.processingStatus = .error("No text field found")
            resetAfterDelay(appState: appState)
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            appState.processingStatus = .error("Text field is empty")
            resetAfterDelay(appState: appState)
            return
        }

        // ── Step 2: Save for Undo ────────────────────────────────

        let appName = textFieldAgent.frontmostAppName ?? "Unknown"
        undoBuffer.save(originalText: text, element: element, appName: appName)

        // ── Step 3: Show loading placeholder in the text field ───

        appState.processingStatus = .rewriting

        let loadingMessage = "ProseKit is rewriting (\(mode.rawValue))..."
        let placeholderLength = loadingMessage.count
        _ = textFieldAgent.writeText(loadingMessage, to: element, originalLength: text.count)

        // ── Step 4: Rewrite via LLM ──────────────────────────────

        let startTime = Date()

        let rewritten: String
        do {
            rewritten = try await engine.rewrite(trimmedText, mode: mode)
        } catch {
            // LLM failed — restore the original text so the user doesn't lose their work
            _ = textFieldAgent.writeText(text, to: element, originalLength: placeholderLength)
            appState.processingStatus = .error("Rewrite failed: \(error.localizedDescription)")
            resetAfterDelay(appState: appState)
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        appState.lastRewriteTime = elapsed

        // Sanity check: model returned something meaningful
        guard !rewritten.isEmpty else {
            // Restore original text on empty response
            _ = textFieldAgent.writeText(text, to: element, originalLength: placeholderLength)
            appState.processingStatus = .error("Model returned empty text")
            resetAfterDelay(appState: appState)
            return
        }

        // ── Step 5: Write rewritten text back ────────────────────

        appState.processingStatus = .writing

        let writeSuccess = textFieldAgent.writeText(rewritten, to: element, originalLength: placeholderLength)

        if writeSuccess {
            appState.processingStatus = .done
            appState.rewriteCount += 1
            resetAfterDelay(appState: appState)
        } else {
            // Fallback: use clipboard method (⌘A → ⌘C → replace → ⌘V)
            let fallback = ClipboardFallback()
            fallback.writeViaClipboard(rewritten)
            appState.processingStatus = .done
            appState.rewriteCount += 1
            resetAfterDelay(appState: appState)
        }
    }

    // MARK: - Undo

    /// Undo the most recent rewrite.
    func undo(appState: AppState) {
        guard undoBuffer.canUndo else {
            appState.processingStatus = .error("Nothing to undo")
            resetAfterDelay(appState: appState)
            return
        }

        let success = undoBuffer.undo()
        if success {
            appState.processingStatus = .done
            appState.rewriteCount = max(0, appState.rewriteCount - 1)
            resetAfterDelay(appState: appState)
        } else {
            appState.processingStatus = .error("Undo failed — text field may have changed")
            resetAfterDelay(appState: appState)
        }
    }

    // MARK: - Helpers

    /// Check accessibility permission and update state.
    func checkAccessibility(appState: AppState) {
        appState.hasAccessibilityPermission = textFieldAgent.hasAccessibilityPermission
    }

    /// Reset processing status to idle after a brief delay (for UI feedback).
    private func resetAfterDelay(appState: AppState, seconds: Double = 2.0) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if case .done = appState.processingStatus {
                appState.processingStatus = .idle
            } else if case .error = appState.processingStatus {
                appState.processingStatus = .idle
            }
        }
    }
}
