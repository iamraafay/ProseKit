# ProseKit

A free, open-source macOS menu bar app that rewrites text in place — in any app — using a local LLM. No cloud, no accounts, no telemetry. Press `⌘⇧G` and your rough draft becomes polished text, right where you typed it.

ProseKit is a local-first alternative to Grammarly. It reads the text from whatever text field you're focused on, rewrites it through a quantized Qwen3-8B model running on Apple Silicon, and writes the result back — all without your text ever leaving your machine.

## How It Works

```
Type rough text in any app (Slack, Mail, Chrome, iMessage, etc.)
        │
        ▼
  Press ⌘⇧G
        │
        ▼
ProseKit reads the text field via macOS Accessibility API
        │
        ▼
Local Qwen3-8B rewrites it (runs on your GPU via Apple MLX)
        │
        ▼
Rewritten text replaces the original in the text field
        │
        ▼
  Don't like it? Press ⌘⇧Z to undo.
```

## Four Modes

| Mode | Shortcut | What It Does |
|------|----------|-------------|
| Grammar Only | `⌘1` | Fix errors only — preserve your voice |
| Concise | `⌘2` | Tighten and trim — same meaning, fewer words |
| Casual | `⌘3` | Friendly and conversational |
| Professional | `⌘4` | Polished and business-appropriate |

Select a mode from the menu bar dropdown, then press `⌘⇧G` from any app.

## Requirements

- macOS 14+ (Sonoma)
- Apple Silicon (M1 or later)
- 8 GB unified memory (minimum)
- ~4.3 GB disk for the model (downloaded on first launch)
- Xcode 15+ (to build from source)

## Build from Source

```bash
git clone https://github.com/iamraafay/ProseKit.git
cd ProseKit
open ProseKit/ProseKit.xcodeproj
```

Press `⌘R` in Xcode to build and run. On first launch, ProseKit downloads the Qwen3-8B-4bit model from HuggingFace (~4.3 GB). Subsequent launches use the cached model.

You'll need to grant Accessibility permission in System Settings → Privacy & Security → Accessibility for ProseKit to read and write text fields in other apps.

## Architecture

ProseKit is a SwiftUI menu bar app (`LSUIElement`) with no dock icon. It embeds Apple's [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) as a Swift Package for on-device inference.

```
ProseKit.app
├── ProseKitApp.swift          App entry point, AppDelegate, model loading
├── RewriteCoordinator.swift   Orchestrates the full pipeline
├── RewriteEngine.swift        LLM inference via mlx-swift-lm
├── RewriteMode.swift          Four modes with optimized few-shot prompts
├── TextFieldAgent.swift       macOS Accessibility API (read/write text fields)
├── ClipboardFallback.swift    Fallback for apps where AX write fails
├── HotkeyManager.swift        Global ⌘⇧G and ⌘⇧Z hotkeys
├── ModelManager.swift         First-launch model download from HuggingFace
├── MenuBarView.swift          SwiftUI menu bar dropdown UI
├── AppState.swift             Observable state container
├── UndoBuffer.swift           Stores originals for undo (max 20)
└── SettingsStore.swift        UserDefaults persistence
```

The rewrite pipeline: hotkey trigger → read text via Accessibility API → save original to undo buffer → show loading placeholder in text field → send to LLM with mode-specific prompt → write result back to text field.

## Research

### Why a Local LLM?

Grammarly uses a hybrid approach: a fast GECToR tagging model for basic grammar, rule-based NLP pipelines, and a cloud LLM for tone/rewriting. That architecture makes sense at scale, but it requires sending every keystroke to Grammarly's servers.

ProseKit takes a simpler approach: one local model, four prompts. This means all four modes work offline, there's no subscription, and your text never leaves your Mac. The tradeoff is that a 8B model can't match a cloud-hosted 70B+ model on quality — but for the 90% case of fixing typos, tightening prose, and adjusting tone in chat messages and emails, it's more than good enough.

### Model Selection

We evaluated five models and chose **Qwen3-8B-Instruct (4-bit quantized)** for the best balance of quality, speed, and memory:

| Model | Size | Verdict |
|-------|------|---------|
| Qwen3-8B-4bit | 4.3 GB | Selected — strong instruction-following, fits 8GB Macs |
| Qwen3-1.7B-4bit | 1.0 GB | Fallback — faster but struggles with grammar correction |
| Llama-3.2-3B | 1.8 GB | Decent but Qwen3-1.7B beats it at half the size |
| Gemma-3-4B | 3.2 GB | Good but not as strong on rewriting tasks |
| Mistral-7B | 4.0 GB | Would need fine-tuning to match Qwen3-8B out-of-box |

### The `/no_think` Discovery

Qwen3 has a chain-of-thought reasoning mode enabled by default. In our initial testing, this caused 15.2s average latency and a 12.5% failure rate (reasoning consumed the entire token budget). Appending `/no_think` to the system prompt disables chain-of-thought and transforms the model's performance:

| Metric | With thinking | With `/no_think` |
|--------|:---:|:---:|
| Average latency | 15.2s | 2.65s |
| Failure rate | 12.5% | 0% |
| `<think>` tags in output | 100% | 0% |

A 5.7x speedup with zero failures. This single directive makes the difference between unusable and production-ready.

### Accessibility API Validation

We tested three approaches for reading/writing text in other apps:

| Approach | Result |
|----------|--------|
| System-wide `AXUIElementCreateSystemWide()` | Failed in all apps |
| PID-based `AXUIElementCreateApplication(pid)` | Works in Messages, Slack, Safari |
| Recursive tree walk | Works but unnecessary (PID-based is sufficient) |

The PID-based approach is our primary method. For Electron apps (Slack, VS Code, Discord), we set `AXEnhancedUserInterface` on the app element to expose the accessibility tree. A clipboard fallback (⌘A → ⌘C → rewrite → ⌘V) handles edge cases where direct AX write fails.

## Prompt Evaluation

All four mode prompts were systematically optimized using a custom evaluation harness. The eval suite lives in `eval/` and tests prompt variants against benchmark datasets and hand-curated samples.

### Grammar Mode

Evaluated 8 prompt variants across 2 rounds against 100 JFLEG samples (a standard grammar correction benchmark with 4 human corrections per sentence).

**Key finding:** Framing the prompt as "produce the smallest possible diff" outperformed listing rules about what not to change. The v1 production prompt had 39% overcorrection — it was rewriting nearly everything. The winning v8 prompt reduced overcorrection to 6.7%.

| Variant | Strategy | GLEU | Overcorrection |
|---------|----------|------|----------------|
| v1_production | Rule-based ("You are a text editor...") | 0.5715 | 38.7% |
| v2_strict_minimal | "Absolute minimum changes" | 0.6701 | 15.1% |
| v7_surgical | "Fix ONLY clear errors" | 0.7069 | 12.8% |
| **v8_minimal_diff** | **"Smallest possible diff"** | **0.7364** | **6.7%** |

Edge case validation confirmed the winning prompt handles homophones, already-correct text, chat-style messages, and ambiguous inputs ("Is this even god?" returned unchanged — it doesn't hallucinate "good").

### Style Modes (Concise, Casual, Professional)

Evaluated 15+ variants across 2 rounds against 44 hand-curated samples with reference outputs and key-term preservation checks.

**Key finding:** Few-shot prompts (showing concrete input/output examples) won every mode. They consistently beat rule-based prompts on composite score, meaning preservation, and stability (returning already-correct text unchanged).

| Mode | Winner | Composite | Meaning | Mode Metric | Stability |
|------|--------|-----------|---------|-------------|-----------|
| Concise | v5_few_shot | 0.6691 | 97.8% | 0.50x compression | 100% |
| Casual | v5_few_shot | 0.6194 | 88.1%* | 0.31 informality | 100% |
| Professional | v6_few_shot_concise | 0.7391 | 97.8% | 0.72 formality | 100% |

*Casual meaning at 88.1% was below the 90% target, but the "failures" were valid synonym substitutions ("position" → "role") that the exact-match metric penalizes unfairly.

### Evaluation Metrics

**Grammar mode** uses GLEU (Ground-truth-based BLEU), the standard metric for grammatical error correction. It penalizes both under-correction and over-correction by comparing n-gram overlap with human references.

**Style modes** use a composite score combining GLEU (30%), meaning preservation via key-term retention (30%), a mode-specific metric (30%), and stability on already-correct inputs (10%). Mode-specific metrics: compression ratio for Concise, informality score (contraction/casual marker density) for Casual, formality score (absence of slang, formal vocabulary) for Professional.

### Running the Eval Suite

```bash
cd eval
pip install -r requirements.txt

# Grammar mode (requires Swama running with Qwen3-8B):
python eval_prompts.py --builtin                    # Quick test (31 samples)
python eval_prompts.py --samples 100 --output results.json  # Full JFLEG eval

# Style modes:
python eval_styles.py --output style_results.json   # All 3 modes, 44 samples

# Quick single-sentence test:
python quick_test.py "I goes to the store yesterday"
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘⇧G` | Rewrite text in the focused text field |
| `⌘⇧Z` | Undo the last rewrite (restore original) |
| `⌘1` through `⌘4` | Switch rewrite mode |

## Technical Details

- **Model:** `mlx-community/Qwen3-8B-4bit` via Apple MLX (Metal GPU acceleration)
- **Inference:** ~1-3 seconds per rewrite on Apple Silicon
- **Temperatures:** Grammar 0.2, Concise 0.4, Professional 0.5, Casual 0.6
- **Max tokens:** 2048 per rewrite
- **App sandbox:** Disabled (required for Accessibility API)
- **Network:** Outbound only, used exclusively for model download from HuggingFace on first launch

## Project Structure

```
ProseKit/
├── ProseKit.xcodeproj/     Xcode project
├── Sources/                All 12 Swift source files
├── Info.plist              LSUIElement, Accessibility usage description
└── ProseKit.entitlements   Network client (for model download)

eval/
├── eval_prompts.py         Grammar prompt evaluation (JFLEG + built-in)
├── eval_styles.py          Style mode evaluation (Concise/Casual/Professional)
├── prompts.py              Grammar prompt variants (8 tested)
├── style_prompts.py        Style prompt variants (15+ tested)
├── builtin_samples.py      31 hand-curated grammar test cases
├── style_samples.py        44 hand-curated style test cases
├── quick_test.py           Single-sentence tester
├── requirements.txt        Python dependencies
└── results_*.json          Evaluation results from each round

docs/
├── prd-grammarly-replacement.md    Product requirements document
├── prosekit-engineering-breakdown.md   Architecture and build plan
└── llm-research-findings.md        Model selection and prompt research

iteration-0/
├── TextFieldAgent.swift    Original Accessibility API proof-of-concept
├── LEARNINGS.md            Accessibility API test results
├── SETUP_AND_TEST_LLM.md   Swama setup + LLM test instructions
├── llm_test_results*.md    LLM quality benchmarks (V1 and V2)
└── test_llm_quality.py     Test suite script
```

## License

MIT

## Credits

Built with [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) by Apple and the [Qwen3](https://huggingface.co/Qwen) model family by Alibaba. Grammar evaluation uses the [JFLEG](https://huggingface.co/datasets/jfleg) dataset.
