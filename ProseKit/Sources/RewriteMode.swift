// RewriteMode.swift
// ProseKit — Defines the four rewrite modes and their LLM prompts.
//
// Each mode has a system prompt engineered to minimize overcorrection.
// The `/no_think` directive at the end disables Qwen3's chain-of-thought,
// which was validated to reduce latency from 15.2s → 2.65s with 0% failure rate.

import Foundation

enum RewriteMode: String, CaseIterable, Identifiable, Codable {
    case grammar = "Grammar Only"
    case concise = "Concise"
    case casual = "Casual"
    case professional = "Professional"

    var id: String { rawValue }

    /// SF Symbol for the menu bar UI.
    var sfSymbol: String {
        switch self {
        case .grammar:      return "textformat.abc"
        case .concise:      return "arrow.down.right.and.arrow.up.left"
        case .casual:       return "face.smiling"
        case .professional: return "briefcase"
        }
    }

    /// Keyboard shortcut character for the mode picker menu.
    var shortcutKey: Character {
        switch self {
        case .grammar:      return "1"
        case .concise:      return "2"
        case .casual:       return "3"
        case .professional: return "4"
        }
    }

    /// Short description shown in the menu bar dropdown.
    var menuDescription: String {
        switch self {
        case .grammar:      return "Fix errors only — preserve your voice"
        case .concise:      return "Tighten and trim — same meaning, fewer words"
        case .casual:       return "Friendly and conversational"
        case .professional: return "Polished and business-appropriate"
        }
    }

    // MARK: - LLM Prompt Configuration

    /// Temperature for this mode. Tuned per-mode during prompt evaluation (2026-02-07).
    var temperature: Float {
        switch self {
        case .grammar:      return 0.2
        case .concise:      return 0.4
        case .casual:       return 0.6
        case .professional: return 0.5
        }
    }

    /// Full system prompt for the LLM. Each mode has a dedicated prompt optimized via eval harness.
    ///
    /// The `/no_think` at the end is a Qwen3-specific soft switch that disables chain-of-thought
    /// reasoning. Without it, the model emits <think>...</think> blocks that consume the token
    /// budget and cause 15s+ latency. With it: 2.65s avg, 0% failures. (Validated 2026-02-06)
    ///
    /// Prompt variants validated on 2026-02-07:
    /// - Grammar: v8_minimal_diff — JFLEG GLEU 0.7364, overcorrection 0.0668
    /// - Concise: v5_few_shot — composite 0.6691, meaning 97.8%, compression 0.50x
    /// - Casual:  v5_few_shot — composite 0.6194, GLEU 0.5441, stability 100%
    /// - Professional: v6_few_shot_concise — composite 0.7391, meaning 97.8%, formality 0.72
    var systemPrompt: String {
        switch self {
        case .grammar:
            return """
            Proofread the following text. Fix any spelling, grammar, or punctuation errors. Your goal is to produce the smallest possible diff — change as few characters as possible while fixing all errors.

            Rules:
            - Output ONLY the corrected text
            - Do NOT rephrase or restructure sentences
            - Do NOT change correct words to synonyms
            - Do NOT add or remove words unless fixing an error
            - If text is correct, return it unchanged

            /no_think
            """

        case .concise:
            return """
            Make the text more concise. Keep all facts and meaning.

            Examples:
            Input: I just wanted to reach out to let you know that the meeting has been rescheduled.
            Output: The meeting has been rescheduled.

            Input: Due to the fact that the server was experiencing issues, we made the decision to restart it.
            Output: We restarted the server due to issues.

            Input: The API returns JSON.
            Output: The API returns JSON.

            Now shorten this text. Output ONLY the result:

            /no_think
            """

        case .casual:
            return """
            Rewrite in a casual, friendly tone. Keep all the same information.

            Examples:
            Input: I would like to inform you that the meeting has been rescheduled to Thursday at 2:00 PM.
            Output: Hey, just a heads up — the meeting's been moved to Thursday at 2 PM.

            Input: Please ensure that all deliverables are submitted prior to the established deadline.
            Output: Make sure to get everything in before the deadline!

            Input: Hey, wanna grab lunch tomorrow?
            Output: Hey, wanna grab lunch tomorrow?

            Now rewrite this text casually. Output ONLY the result:

            /no_think
            """

        case .professional:
            return """
            Rewrite in a professional, business-appropriate tone. Keep all facts and key terms. Be concise — don't over-formalize.

            Examples:
            Input: hey so the numbers look pretty good this quarter, revenue is up like 15%
            Output: This quarter's results are strong — revenue increased 15%, exceeding our targets.

            Input: the deploy broke prod, we're rolling back now
            Output: A production incident occurred during deployment. We are currently executing a rollback.

            Input: tbh i dont think this approach is gonna work
            Output: I have concerns about the viability of this approach.

            Input: Please find attached the quarterly report for your review.
            Output: Please find attached the quarterly report for your review.

            Now rewrite this text professionally. Output ONLY the result:

            /no_think
            """
        }
    }
}
