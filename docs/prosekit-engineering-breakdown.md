# ProseKit — Engineering Breakdown & Build Plan

**Philosophy:** Build the riskiest thing first. Each iteration produces a runnable artifact you can demo. Never go more than a day without something working.

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        ProseKit.app                             │
│                    (Swift / SwiftUI)                             │
│                                                                 │
│  ┌──────────┐  ┌──────────────┐  ┌───────────┐  ┌───────────┐ │
│  │ Menu Bar │  │   Hotkey     │  │  Settings  │  │   Undo    │ │
│  │   UI     │  │  Manager     │  │   Store    │  │  Buffer   │ │
│  └────┬─────┘  └──────┬───────┘  └─────┬─────┘  └─────┬─────┘ │
│       │               │                │               │       │
│       └───────────────┼────────────────┼───────────────┘       │
│                       │                │                       │
│                       ▼                │                       │
│              ┌────────────────┐        │                       │
│              │  Rewrite       │        │                       │
│              │  Coordinator   │◄───────┘                       │
│              │  (orchestrates │                                 │
│              │   the pipeline)│                                 │
│              └───────┬────────┘                                 │
│                      │                                          │
│           ┌──────────┼──────────┐                               │
│           ▼                     ▼                               │
│  ┌────────────────┐   ┌────────────────┐                       │
│  │ TextFieldAgent │   │  RewriteEngine │                       │
│  │                │   │                │                       │
│  │ • findFocused  │   │ • MLX runtime  │                       │
│  │   TextField()  │   │ • load model   │                       │
│  │ • readText()   │   │ • rewrite(     │                       │
│  │ • writeText()  │   │     text,      │                       │
│  │ • fallback to  │   │     mode)      │                       │
│  │   clipboard    │   │ • mode prompts │                       │
│  │                │   │                │                       │
│  │ [Accessibility │   │ [MLX Swift     │                       │
│  │  API]          │   │  bindings]     │                       │
│  └────────────────┘   └────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Key Modules

**1. TextFieldAgent** — The hardest part. Talks to macOS Accessibility API.
- `findFocusedTextField()` → walks the AX tree to find the focused text input element
- `readText()` → reads AXValue from the focused element
- `writeText(newText)` → sets AXValue on the focused element
- `fallbackViaClipboard()` → select-all, copy, rewrite, paste (for apps where AX doesn't work)

**2. RewriteEngine** — The LLM brain.
- Loads a quantized model via MLX Swift
- Holds mode-specific system prompts
- `rewrite(text: String, mode: RewriteMode) -> String`
- Streams output for progress indication

**3. RewriteCoordinator** — The glue. Orchestrates the full pipeline.
- Receives hotkey trigger
- Calls TextFieldAgent.readText()
- Saves original to UndoBuffer
- Calls RewriteEngine.rewrite()
- Calls TextFieldAgent.writeText()
- Updates UI state (loading → done)

**4. HotkeyManager** — Registers global keyboard shortcuts via Carbon/CGEvent.

**5. UndoBuffer** — Stores the last N original texts so ⌘Z can restore them.

**6. SettingsStore** — UserDefaults-backed preferences (default mode, hotkey, launch at login).

**7. Menu Bar UI** — SwiftUI status bar item with mode selector, settings, and processing indicator.

---

## Build Iterations

### Iteration 0: Prove the Risk (Day 1)
> "Can we actually read and write text in other apps' text fields?"

This is the make-or-break question. If Accessibility API doesn't work reliably, the whole product concept changes. Prove it before writing any UI.

**User Story:**
> As a developer, I want to run a command-line Swift script that reads the text from whatever text field I'm currently focused on (in any app) and prints it to the terminal — so I know the Accessibility API approach is viable.

**Build:**
- Single-file Swift script (not even an Xcode project yet)
- Request Accessibility permission
- Find the focused AXUIElement
- Read AXValue → print it
- Set AXValue to "Hello from ProseKit!" → verify it appears in the text field
- Test in: Notes, Safari, Chrome, Slack, Mail, VS Code

**Deliverable:** A terminal command you run, click into a text field in Slack, run the command, and see the text printed. Then it writes "Hello from ProseKit!" back into that field.

**Pass/fail criteria:**

| App | Read works? | Write works? |
|-----|------------|-------------|
| Notes | ? | ? |
| Safari (text input) | ? | ? |
| Chrome (text input) | ? | ? |
| Slack | ? | ? |
| Mail (compose) | ? | ? |
| VS Code | ? | ? |

If write fails in some apps → build the clipboard fallback (select-all, copy, modify, paste) and note which apps need it.

**Done when:** You can read AND write text fields in at least 4 of 6 target apps.

---

### Iteration 1: Menu Bar + Hotkey Shell (Day 2)
> "I can trigger an action from anywhere on my Mac."

**User Stories:**
> As a Mac user, I want to see a ProseKit icon in my menu bar so I know the app is running.

> As a Mac user, I want to press ⌘⇧G from any app and have ProseKit respond (even if it just logs "triggered!" for now).

**Build:**
- Xcode project: SwiftUI menu bar app (LSUIElement = true, no dock icon)
- Menu bar icon (use SF Symbol `textformat.abc` as placeholder)
- Click menu bar → dropdown with: mode selector (4 modes), separator, "Quit"
- Register global hotkey ⌘⇧G using `CGEvent.tapCreate` or `NSEvent.addGlobalMonitorForEvents`
- On hotkey press → print to console + flash the menu bar icon

**Deliverable:** An app you build and run, icon appears in menu bar, pressing ⌘⇧G from anywhere prints a log message.

**Done when:** Hotkey triggers reliably from any app, menu bar shows mode options.

---

### Iteration 2: Read → Echo → Write (Day 2–3)
> "ProseKit can touch my text."

Wire Iteration 0's Accessibility code into Iteration 1's app shell. No LLM yet — just prove the full read/write loop works from the hotkey.

**User Story:**
> As a Mac user, I want to press ⌘⇧G while typing in Slack, and have ProseKit read my text, convert it to UPPERCASE, and write it back into the Slack text field — so I can see the full pipeline works end-to-end.

**Build:**
- Integrate TextFieldAgent into the app
- Hotkey → read text → transform (uppercase as placeholder) → write back
- Add UndoBuffer: store original text before overwriting
- Handle the clipboard fallback path for apps where AXValue write fails
- Menu bar icon animates (changes SF Symbol) while "processing"

**Deliverable:** Type "hello world" in Slack, press ⌘⇧G, text becomes "HELLO WORLD" in the Slack text field. Press ⌘Z to undo.

**Done when:** The read → transform → write loop works in target apps. Undo works.

---

### Iteration 3: Local LLM Integration (Day 3–4)
> "ProseKit can think."

Replace the uppercase transform with actual LLM rewriting.

**User Stories:**
> As a Mac user, I want ProseKit to rewrite my rough Slack message into clean, grammatically correct text — powered by a local model, with no internet required.

> As a user, I want to choose between Grammar Only, Concise, Casual, and Professional modes so the rewrite matches my context.

**Build:**
- Add MLX Swift as a dependency (Swift Package Manager)
- Download and bundle a quantized model (start with Qwen2.5-3B-Instruct-4bit or test alternatives)
- Implement RewriteEngine:
  - Load model on app launch (show loading state in menu bar)
  - Four system prompts, one per mode
  - `rewrite(text, mode)` → returns rewritten string
- Wire into RewriteCoordinator: hotkey → read → rewrite → write back
- Menu bar shows currently selected mode
- Switching mode via menu bar dropdown

**Prompt templates:**

```
// Grammar Only
System: Fix grammar, spelling, and punctuation errors in the user's text.
Return ONLY the corrected text. No explanations. Preserve the author's
voice, structure, and meaning. If the text has no errors, return it unchanged.

// Concise
System: Rewrite the user's text to be more concise. Remove filler words,
redundancy, and unnecessary qualifiers. Keep the core meaning intact.
Return ONLY the rewritten text. No explanations.

// Casual
System: Rewrite the user's text in a casual, friendly tone. Make it sound
natural and conversational, like a message to a colleague you're comfortable
with. Return ONLY the rewritten text. No explanations.

// Professional
System: Rewrite the user's text in a professional, polished tone. Make it
clear, well-structured, and appropriate for business communication.
Return ONLY the rewritten text. No explanations.
```

**Deliverable:** Type a rough message in any app, press ⌘⇧G, get a genuinely rewritten version back in the text field.

**Done when:** All four modes produce reasonable output. Latency is < 5 seconds for a paragraph (we'll optimize to < 3 in the next iteration).

---

### Iteration 4: Polish & Edge Cases (Day 5–6)
> "ProseKit feels solid."

**User Stories:**
> As a user, I want visual feedback when ProseKit is processing my text so I know it's working and hasn't frozen.

> As a user, I want ProseKit to handle edge cases gracefully — empty text fields, very long text, text with special characters, formatted text (bold/links in Slack).

> As a user who writes in multiple apps, I want ProseKit to work reliably whether I'm in Slack, Chrome, Mail, or Notes.

**Build:**
- Polish menu bar UI:
  - Show current mode as text/color next to icon
  - Animate icon during LLM processing (spinning or pulsing)
  - Show "Done ✓" briefly after successful rewrite
  - Show error state if something fails
- Edge case handling:
  - Empty text field → do nothing, flash icon to indicate "nothing to rewrite"
  - Very long text (> 500 words) → warn user or truncate to model context window
  - Rich text / HTML (Slack formatting) → strip to plain text, rewrite, paste back
  - Text fields where Accessibility read works but write fails → clipboard fallback
  - Multiple monitors, multiple desktops → ensure focused element detection works
- Performance optimization:
  - Keep model loaded in memory (don't reload per rewrite)
  - Measure and log latency
  - If > 3 seconds, investigate: model size? quantization? prompt length?
- Modifier hotkey for mode picker:
  - ⌘⇧G → rewrite with default mode (instant)
  - ⌘⇧⌥G → show small popover with four mode buttons → pick one → rewrite

**Deliverable:** A polished, reliable rewriting experience that handles real-world usage.

**Done when:** You can use ProseKit for a full workday across Slack, Mail, and Chrome without it breaking.

---

### Iteration 5: Test & Ship (Day 7)
> "ProseKit is ready for other people to try."

**User Stories:**
> As a user downloading ProseKit for the first time, I want a simple setup experience — download, open, grant Accessibility permission, done.

> As a developer who wants to contribute, I want a clean README and build instructions so I can get the project running locally.

**Build:**
- Quality pass:
  - Test 30 text samples across all four modes, rate output quality
  - Fix any prompts that produce bad results
  - Benchmark latency across different text lengths
  - Test on M1 (8GB), M1 Pro (16GB), M2, M3 if available
- First-run experience:
  - On first launch, show a setup window requesting Accessibility permission
  - Link to System Settings → Privacy → Accessibility
  - Show a quick tutorial: "Type anywhere → Press ⌘⇧G → Text gets rewritten"
- Distribution:
  - Create a signed .dmg or .zip for direct download
  - Homebrew formula (if time allows)
  - Write README with: what it does, demo GIF, install instructions, build from source
- GitHub repo:
  - MIT license
  - CONTRIBUTING.md
  - Issue templates
  - Initial release tag (v0.1.0)

**Deliverable:** A GitHub release that someone can download, install, and use in under 2 minutes.

---

## Full User Story Backlog (Prioritized)

### P0 — MVP (Week 1)

| ID | User Story | Iteration | Estimate |
|----|-----------|-----------|----------|
| US-01 | As a developer, I can read text from a focused text field via Accessibility API | 0 | 4h |
| US-02 | As a developer, I can write text back to a focused text field via Accessibility API | 0 | 4h |
| US-03 | As a user, I see a ProseKit icon in my menu bar when the app is running | 1 | 2h |
| US-04 | As a user, I can press ⌘⇧G from any app to trigger ProseKit | 1 | 3h |
| US-05 | As a user, pressing ⌘⇧G reads my text, rewrites it, and puts it back in the text field | 2 | 4h |
| US-06 | As a user, I can ⌘Z to undo a rewrite and get my original text back | 2 | 3h |
| US-07 | As a user, my text is rewritten by a local LLM, not sent to the cloud | 3 | 8h |
| US-08 | As a user, I can choose between Grammar Only, Concise, Casual, and Professional modes | 3 | 4h |
| US-09 | As a user, I see visual feedback (icon animation) while ProseKit is processing | 4 | 2h |
| US-10 | As a user, ProseKit handles edge cases (empty fields, long text, rich text) gracefully | 4 | 6h |
| US-11 | As a user, I can set a default rewrite mode in settings | 4 | 2h |
| US-12 | As a new user, I get a clear setup flow to grant Accessibility permissions | 5 | 3h |
| US-13 | As a developer, I can build and run ProseKit from source with clear README instructions | 5 | 3h |

### P1 — Polish (Weeks 2–4)

| ID | User Story | Estimate |
|----|-----------|----------|
| US-14 | As a user, I can press ⌘⇧⌥G to see a mode picker before rewriting | 4h |
| US-15 | As a user, I see a floating rewrite button near active text fields | 8h |
| US-16 | As a user, I can see a before/after diff of what ProseKit changed | 6h |
| US-17 | As a user, I can create custom rewrite modes with my own prompts | 4h |
| US-18 | As a user, ProseKit auto-selects the right mode based on which app I'm in | 3h |
| US-19 | As a user, I can select a portion of text and rewrite just that selection | 4h |
| US-20 | As a user, I can route rewrites through Ollama if I prefer a different model | 6h |

---

## Technical Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Accessibility API can't write to Electron apps (Slack, VS Code, Discord) | **High** | High | Clipboard fallback: select-all → copy → rewrite → paste. Test in Iteration 0. |
| 3B model produces low-quality rewrites (changes meaning, sounds robotic) | Medium | High | Benchmark multiple models in Iteration 3. Prompt engineering. Fall back to grammar-only mode if creative modes underperform. |
| LLM latency > 5 seconds on M1 8GB | Medium | Medium | Use smaller model (Gemma-2-2B at 1.4GB). Optimize MLX settings. Show progress indicator so user knows it's working. |
| macOS Accessibility permission UX is confusing for non-technical users | Medium | Medium | First-run setup wizard with screenshots. Link directly to System Settings. |
| Rich text (Slack formatting, links) gets mangled during rewrite | **High** | Medium | Strip to plain text before rewriting. Warn user if formatting will be lost. Long-term: preserve formatting markers. |
| Global hotkey conflicts with other apps | Low | Low | Make hotkey configurable in settings. Default ⌘⇧G is rarely taken. |

---

## Dev Environment Setup

```bash
# Requirements
# - macOS 14+ (Sonoma)
# - Xcode 15+
# - Apple Silicon Mac (M1 or later)

# Clone and build
git clone https://github.com/yourname/prosekit.git
cd prosekit
open ProseKit.xcodeproj
# Build and run (⌘R)

# Download the model (one-time)
# MLX community models on Hugging Face
huggingface-cli download mlx-community/Qwen2.5-3B-Instruct-4bit \
  --local-dir ~/Library/Application\ Support/ProseKit/models/qwen-3b
```

---

## Day-by-Day Schedule

| Day | Focus | Deliverable |
|-----|-------|-------------|
| **Day 1** | Iteration 0: Accessibility API proof-of-concept | Terminal script that reads/writes text fields in 4+ apps |
| **Day 2** | Iteration 1 + 2: Menu bar shell, hotkey, wired read/write | App with menu bar icon. ⌘⇧G uppercases text in any text field. |
| **Day 3** | Iteration 3 (part 1): MLX integration, model loading | Model loads on launch. Can rewrite text via hardcoded test call. |
| **Day 4** | Iteration 3 (part 2): Full pipeline, all four modes | ⌘⇧G rewrites text with LLM. Mode switching works. |
| **Day 5** | Iteration 4: Edge cases, error handling, performance | Handles empty fields, long text, clipboard fallback. < 3s latency. |
| **Day 6** | Iteration 4 (cont.): Polish UI, modifier hotkey, undo | Mode picker popover. Reliable undo. Icon animation. |
| **Day 7** | Iteration 5: Test, first-run UX, README, GitHub release | v0.1.0 shipped. Someone else can install and use it. |
