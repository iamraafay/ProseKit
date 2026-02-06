# PRD: ProseKit — One-Click Text Rewriter for macOS

**Author:** Raafay
**Date:** February 6, 2026
**Status:** Draft v0.2
**Version:** 0.2 — Updated to reflect inline rewrite interaction model

---

## Problem Statement

Every day, Mac users write messages in Slack, emails in Mail, comments in Jira, and posts in browsers — and the text is often rough. Grammarly solves this but costs $144/year and sends every keystroke to the cloud. There is no open-source, local-first tool that lets you **rewrite text directly inside any text field on macOS** with a single click. Users want a floating "polish this" button that appears next to any text field and rewrites their draft in place — fixing grammar, improving clarity, or adjusting tone — without ever leaving the app they're in.

## Goals

1. **Ship an MVP in 1 week**: a menu bar app with a global hotkey that rewrites the text in the active text field in place, with selectable rewrite modes
2. **Run entirely on-device** — zero text leaves the user's Mac, ever
3. **One-click rewriting, not suggestion-by-suggestion review** — the tool rewrites the full text and replaces it in the field; the user's job is to choose the mode, not review individual fixes
4. **Multiple rewrite modes**: Professional, Casual, Concise, and Grammar-Only — so the same tool works in Slack, email, docs, and code reviews
5. **Free and open-source** under a permissive license (MIT or Apache 2.0)

## Non-Goals

- **Not a suggestion-by-suggestion grammar checker.** This is not Grammarly's UX of underlining words and showing popups per error. It rewrites the whole text in place. One click, done.
- **Not a writing editor.** No writing surface. It improves text wherever you already write.
- **Not a cloud service.** No accounts, no telemetry, no server-side processing.
- **Not cross-platform.** macOS only. Deep native integration is the product advantage.
- **Not a translation tool.** English-first. Multi-language is future scope.

## User Stories

### General Consumer
- As a **Mac user writing a Slack message**, I want to press a shortcut and have my rough draft instantly rewritten into a clean, clear message — right in the Slack text box — so I don't have to proofread or second-guess my wording.
- As a **privacy-conscious user**, I want all rewriting to happen on my device so none of my messages, emails, or documents are sent to external servers.

### Professional
- As a **professional composing an email**, I want to choose "Professional" mode and have my casual draft rewritten with proper tone and structure — directly in the compose window — so I sound polished without effort.
- As a **non-native English speaker**, I want to type my rough thoughts and press one key to get fluent, natural English back in the same text field.

### Developer
- As a **developer writing a PR description**, I want to hit a shortcut and have my bullet points restructured into a clear, well-organized summary — in place — so my technical writing is precise without manual editing.
- As an **open-source contributor**, I want to extend the tool with custom rewrite modes (e.g., "Technical", "ELI5") so it fits my specific workflow.

## Core Interaction Model

This is the key design decision that differentiates ProseKit from Grammarly:

```
User types rough text in any app (Slack, Mail, Chrome, VS Code, etc.)
        │
        ▼
User triggers ProseKit:
  OPTION A: Global hotkey (e.g., ⌘⇧G) → uses last-used mode
  OPTION B: Global hotkey (e.g., ⌘⇧⌥G) → shows mode picker first
  OPTION C (future): Floating button near active text fields
        │
        ▼
ProseKit reads the text field content via Accessibility API
        │
        ▼
Local LLM rewrites the text according to selected mode:
  🔵 Grammar Only — fix errors, keep everything else
  🟢 Concise — tighten, remove filler, keep meaning
  🟡 Casual — friendly, conversational tone
  🟠 Professional — polished, formal tone
        │
        ▼
Rewritten text replaces the original in the text field
(User can ⌘Z to undo if they don't like the result)
```

**The interaction is: type → trigger → done.** No reviewing individual suggestions. No popups to dismiss. The text in the field just gets better.

## Requirements

### Must-Have (P0) — Week 1 MVP

| # | Requirement | Acceptance Criteria |
|---|------------|-------------------|
| P0-1 | **Menu bar app** that lives in the macOS status bar | App launches at login, shows icon in menu bar, click to access settings and mode selection |
| P0-2 | **Global keyboard shortcut** to trigger rewrite | User presses ⌘⇧G → text in the currently focused text field is captured, rewritten, and replaced in place |
| P0-3 | **Read text from active text field** via Accessibility API | Reliably reads text content from the focused text input in Slack, Mail, Chrome, Safari, Notes, VS Code, and Terminal |
| P0-4 | **Write rewritten text back** into the text field | After LLM processing, the rewritten text replaces the original content in the same text field. Must preserve cursor focus. |
| P0-5 | **Four rewrite modes**: Grammar Only, Concise, Casual, Professional | Each mode uses a distinct system prompt. User can set a default mode and switch via menu bar or modifier hotkey. |
| P0-6 | **Local LLM inference** via MLX | All processing on-device. No network calls. Works offline. Rewrite latency < 3 seconds for a paragraph (< 200 words). |
| P0-7 | **Works on Apple Silicon** (M1+) | Uses Metal GPU acceleration. Minimum 8GB unified memory. |
| P0-8 | **Undo support** | User can press ⌘Z immediately after rewrite to restore original text. ProseKit preserves the original in clipboard or memory. |
| P0-9 | **Visual feedback during processing** | Menu bar icon animates or changes color while LLM is processing, so user knows it's working |

### Nice-to-Have (P1) — Weeks 2–4

| # | Requirement | Acceptance Criteria |
|---|------------|-------------------|
| P1-1 | **Floating rewrite button** near active text fields | A small, unobtrusive button appears near detected text fields. Clicking it triggers rewrite. Drag to reposition. |
| P1-2 | **Mode picker popover** | Alternative hotkey (⌘⇧⌥G) shows a small popover with mode buttons before rewriting, for when user wants to pick a specific mode |
| P1-3 | **Before/after diff view** | Optional: after rewriting, show a popover with a diff of what changed, with accept/revert buttons |
| P1-4 | **Custom rewrite modes** | Users can create custom modes with their own system prompts (e.g., "Technical", "ELI5", "Hemingway") |
| P1-5 | **App-specific default modes** | Auto-select mode based on active app: Professional for Mail, Casual for Slack, Concise for Jira |
| P1-6 | **Multiple model support** via Ollama | Users who run Ollama can route rewrites to any local model of their choice |
| P1-7 | **Partial text rewrite** | If user selects a portion of text before triggering, only rewrite the selection — not the entire field |

### Future Considerations (P2)

| # | Requirement | Acceptance Criteria |
|---|------------|-------------------|
| P2-1 | **Real-time inline suggestions** | Underline potential improvements as user types (closer to classic Grammarly UX), as an optional mode |
| P2-2 | **Browser extension** | Chrome/Safari extension for web apps where Accessibility API can't reach (Google Docs, Notion) |
| P2-3 | **Optional cloud LLM** | Users can plug in their own API key for higher-quality rewrites |
| P2-4 | **Writing style learning** | LLM adapts to user's personal writing style over time from accepted rewrites |
| P2-5 | **Multi-language support** | Rewriting in Spanish, French, German, etc. |
| P2-6 | **iOS / iPad companion** | Keyboard extension that brings the same rewrite modes to iOS |

## Technical Approach

### LLM Engine: Apple MLX with Quantized Model

**Why MLX:** It's Apple's ML framework, purpose-built for Apple Silicon's unified memory. It gives the best inference performance on M-series chips — significantly faster than llama.cpp for the same model size.

**Model selection:** A quantized 3B-parameter model hits the sweet spot for rewrite quality vs. speed. Candidates to benchmark:

| Model | Size (4-bit) | Strengths |
|-------|-------------|-----------|
| Qwen2.5-3B | ~1.8 GB | Strong instruction-following, good at structured rewriting |
| Phi-3.5-mini (3.8B) | ~2.2 GB | Excellent at concise, clear English |
| Gemma-2-2B | ~1.4 GB | Smallest footprint, good grammar correction |

**Recommendation:** Start with Qwen2.5-3B-Instruct (4-bit quantized). It has the best balance of rewrite quality and speed for this use case. Fall back to Gemma-2-2B if memory constraints are too tight on 8GB machines.

### Prompt Strategy

Each rewrite mode maps to a distinct system prompt. The key design principle: **the prompt must instruct the model to return ONLY the rewritten text** — no explanations, no "here's your corrected text:", no markdown formatting. Just the clean rewritten output, ready to paste back.

Example prompt structure:
```
System: You are a writing assistant. Rewrite the user's text to be more {mode}.
Rules:
- Return ONLY the rewritten text. No explanations, no preamble.
- Preserve the original meaning and intent.
- Keep proper nouns, technical terms, and URLs unchanged.
- Match the approximate length of the original (unless mode is "Concise").

User: {text from text field}
```

### Architecture (MVP)

```
┌──────────────────────────────────────────────────┐
│               macOS Menu Bar App                 │
│            (Swift / SwiftUI)                     │
├──────────────┬───────────────────────────────────┤
│ Hotkey       │ Global shortcut listener (⌘⇧G)   │
│ Listener     │ Triggers rewrite pipeline         │
├──────────────┼───────────────────────────────────┤
│ Text         │ macOS Accessibility API            │
│ Capture      │ AXUIElement → AXValue             │
│              │ Reads focused text field content   │
├──────────────┼───────────────────────────────────┤
│ Rewrite      │ MLX Swift bindings                │
│ Engine       │ Quantized 3B model                │
│              │ Mode-specific system prompts       │
│              │ Returns clean rewritten text only  │
├──────────────┼───────────────────────────────────┤
│ Text         │ Accessibility API: set AXValue     │
│ Replacement  │ Writes rewritten text back to      │
│              │ the same text field                │
│              │ Fallback: clipboard paste (⌘V)     │
├──────────────┼───────────────────────────────────┤
│ Undo         │ Stores original text in memory     │
│ Buffer       │ ⌘Z restores via Accessibility API  │
│              │ or clipboard                       │
├──────────────┼───────────────────────────────────┤
│ Status UI    │ Menu bar icon animation            │
│              │ Mode indicator                     │
│              │ Settings panel                     │
└──────────────┴───────────────────────────────────┘
```

**Accessibility API is the critical dependency.** The app needs macOS Accessibility permissions (System Settings → Privacy & Security → Accessibility) to read and write text fields in other apps. This is the same permission Grammarly, TextExpander, and Bartender request.

**Fallback path:** If the Accessibility API can't read/write a specific text field (some Electron apps are problematic), fall back to: select-all → copy → rewrite → paste. Less elegant but works everywhere.

## Success Metrics

### Leading Indicators (Week 1–2)

| Metric | Target |
|--------|--------|
| MVP builds and runs on M1+ Mac | Yes/No |
| Rewrite latency for a paragraph (< 200 words) | < 3 seconds |
| Accessibility API works in target apps (Slack, Mail, Chrome, Safari, Notes, VS Code) | ≥ 4 of 6 apps |
| Rewrite quality: manual A/B test of 30 text samples (original vs. rewritten) | Rewritten preferred ≥ 80% of the time |
| ⌘Z undo works reliably after rewrite | 100% |

### Lagging Indicators (Month 1–3)

| Metric | Target |
|--------|--------|
| GitHub stars within first month | 500+ |
| Weekly active users (opt-in telemetry) | 1,000+ |
| Most-used rewrite mode | Track to inform defaults |
| User-reported "rewrite made it worse" rate | < 10% |
| Average rewrites per user per day | 5+ |

## Open Questions

| Question | Owner | Priority |
|----------|-------|----------|
| Which apps does the macOS Accessibility API reliably support for both read AND write of text fields? Need to test Slack (Electron), Chrome, Safari, Mail, Notes, VS Code, and Discord. | Engineering | **Blocking** |
| What's the minimum Mac configuration? M1 with 8GB can run a 4-bit 3B model, but what about memory pressure when Slack + Chrome are already using 6GB? | Engineering | High |
| Which base model gives the best rewrite quality after quantization? Need a benchmark suite of 50+ text samples across all four modes. | Engineering | High |
| Should undo be handled via Accessibility API (set AXValue back to original) or via simulated ⌘Z keypress? The latter integrates with each app's native undo stack. | Engineering | Medium |
| What license should the fine-tuned/quantized model use? Must be compatible with MIT/Apache for the app. | Legal / Raafay | Medium |
| App distribution: Mac App Store (sandboxing conflicts with Accessibility API), Homebrew, or direct DMG download? | Engineering | Medium |

## Timeline — Phased Approach

### Phase 1: MVP (Week 1)

**Goal:** A menu bar app that rewrites text in any text field via global hotkey.

- Day 1–2: Swift menu bar app shell, global hotkey registration, Accessibility API prototype (read/write text fields)
- Day 3–4: MLX integration, model loading, prompt engineering for four rewrite modes
- Day 5: Wire it all together — hotkey → read → rewrite → replace. Undo buffer.
- Day 6–7: Test across Slack, Mail, Chrome, Safari, Notes, VS Code. Fix edge cases. Polish status bar UI.

**MVP delivers:** Press ⌘⇧G → text in the focused text field gets rewritten in the default mode. Change mode via menu bar. ⌘Z to undo.

### Phase 2: Polish (Weeks 2–4)

- Floating rewrite button near text fields (P1-1)
- Mode picker popover with ⌘⇧⌥G (P1-2)
- Before/after diff view (P1-3)
- App-specific default modes (P1-5)
- Partial text selection rewrite (P1-7)
- Robust edge case handling, multi-monitor, multi-desktop
- Public GitHub repo, README, contributing guide, Homebrew formula

### Phase 3: Growth (Months 2–3)

- Custom rewrite modes with user-defined prompts (P1-4)
- Ollama integration (P1-6)
- Browser extension for web apps (P2-2)
- Optional cloud LLM support (P2-3)
- Community feedback → reprioritize P2 backlog

---

*This is a living document. Update as decisions are made and questions are resolved.*
