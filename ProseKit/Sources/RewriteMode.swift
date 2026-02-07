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

    /// Temperature for this mode. Grammar uses lower temp for conservative corrections.
    var temperature: Float {
        switch self {
        case .grammar: return 0.3
        default:       return 0.7
        }
    }

    /// The mode-specific instruction inserted into the system prompt.
    private var modeInstruction: String {
        switch self {
        case .grammar:
            return "fix ONLY grammar, spelling, and punctuation errors. Do not change word choice, tone, or sentence structure."
        case .concise:
            return "make the text shorter and tighter. Remove filler words, redundancy, and unnecessary qualifiers. Keep the core meaning."
        case .casual:
            return "rewrite in a casual, friendly tone. Make it sound natural and conversational."
        case .professional:
            return "rewrite in a polished, professional tone. Make it clear, well-structured, and appropriate for business communication."
        }
    }

    /// Full system prompt for the LLM. Includes anti-overcorrection rules and /no_think directive.
    ///
    /// The `/no_think` at the end is a Qwen3-specific soft switch that disables chain-of-thought
    /// reasoning. Without it, the model emits <think>...</think> blocks that consume the token
    /// budget and cause 15s+ latency. With it: 2.65s avg, 0% failures. (Validated 2026-02-06)
    var systemPrompt: String {
        """
        You are a text editor. You \(modeInstruction).

        RULES — follow these exactly:
        1. Return ONLY the corrected/rewritten text. No explanations, no preamble, no markdown.
        2. Do NOT add information that wasn't in the original.
        3. Do NOT remove sentences unless the mode is "Concise".
        4. Preserve all proper nouns, technical terms, URLs, and @mentions exactly.
        5. Preserve the original paragraph/line break structure.
        6. If the text is already good, return it unchanged.
        7. Keep the same approximate length (±20%) unless mode is "Concise".
        8. Do NOT wrap your response in quotes.

        /no_think
        """
    }
}
