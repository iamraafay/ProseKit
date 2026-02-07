# LLM Research Findings — ProseKit AI Engine

## How Grammarly Does It

Grammarly uses a **hybrid approach**, not a single model:

1. **GECToR (Tag, Not Rewrite)** — their open-source model that *tags* tokens with corrections instead of regenerating text. Uses a Transformer encoder (RoBERTa). Inference is 10x faster than sequence-to-sequence models. F₀.₅ score of 71.8 on BEA-2019. This handles basic grammar, spelling, punctuation.

2. **Rule-based systems** — classic NLP pipeline: tokenization → POS tagging → syntactic parsing → semantic analysis. Catches patterns that ML models miss.

3. **Generative AI (LLM)** — added post-2023 for tone adjustment, rewriting, and "help me write" features. This is the layer that does what we want ProseKit to do.

**Key insight:** Grammarly didn't start with an LLM. They layered it on top of a fast, efficient tagging system. For our MVP, we're going straight to the LLM approach because our interaction model is different — we're doing full-text rewrites, not inline suggestion-by-suggestion corrections.

## Two Approaches We Could Take

### Approach A: Small LLM for Full Rewriting (Our Plan)
Use a 1.7B–8B instruction-tuned model to rewrite the entire text.

**Pros:** Handles all four modes (grammar, concise, casual, professional) with one model. Simpler architecture. Can restructure sentences, not just fix errors.

**Cons:** Slower than tagging. Risk of overcorrection — small models (<7B) can change meaning, add/remove sentences, or go off-task. Needs careful prompt engineering.

### Approach B: GECToR-Style Tagging for Grammar, LLM for Rewriting
Use GECToR or similar for grammar-only mode (fast, precise). Use LLM for the creative modes.

**Pros:** Grammar-only mode would be nearly instant. Less risk of overcorrection for simple fixes.

**Cons:** Two systems to maintain. GECToR is Python/PyTorch — would need to convert to CoreML or run as a subprocess. More complex architecture for an MVP.

**Decision: Go with Approach A for MVP.** One model, four prompts. Simpler to build, test, and iterate. We can always add GECToR-style tagging later for a "lightning grammar" mode.

## Framework: MLX Swift via Swama

**Swama** is the clear winner for our use case:

- Native Swift menu bar app built on MLX — literally our same architecture
- OpenAI-compatible API (`/v1/chat/completions`) with streaming
- One-command model download (`swama pull qwen3`)
- 50–120 tok/s on M3 Max
- Already handles model loading, quantization, memory management

**Two integration paths:**

1. **Use Swama as a local server** — install Swama, run `swama serve`, hit its API from our app. Simplest to start. Dependency on Swama being installed.

2. **Use SwamaKit as a Swift dependency** — embed the inference engine directly in ProseKit. No external dependency. More work upfront.

**Decision: Start with Swama as a local server for MVP.** This gets us running in hours instead of days. Migrate to embedded SwamaKit later if we want a single-binary app.

## Model Selection

### The Contenders

| Model | Params | Size (4-bit) | Speed (est.) | Grammar Quality | Rewrite Quality |
|-------|--------|-------------|-------------|----------------|----------------|
| **Qwen3-1.7B-Instruct** | 1.7B | ~1.0 GB | Very fast | Decent | May overcorrect |
| **Qwen3-8B-Instruct** | 8B | ~4.3 GB | Fast | Good | Good |
| **Llama-3.2-3B-Instruct** | 3B | ~1.8 GB | Fast | Decent | Decent |
| **Mistral-7B (fine-tuned)** | 7B | ~4.0 GB | Fast | Very good (with QLoRA fine-tuning) | Good |
| **Gemma-3-4B-it** | 4B | ~3.2 GB | Fast | Good | Good |

### Research Says

- **Models <3B parameters struggle with grammar correction** — they tend to answer questions about the text instead of correcting it, and strict prompting only partially helps.
- **Qwen3-1.7B matches Qwen2.5-3B performance** on most benchmarks thanks to better training. Half the parameters, same quality.
- **Fine-tuning matters more than model size** for grammar correction. A fine-tuned Mistral-7B outperforms Llama-2-13B out-of-box.
- **Overcorrection is the main risk** — LLMs tend to change correct text, add words, or restructure things that didn't need restructuring.

### Recommendation

**Primary: Qwen3-8B-Instruct (4-bit quantized)**
- Best balance of quality and speed for rewriting
- 4.3 GB — fits comfortably on any M1+ Mac with 8GB
- Strong instruction-following, good at structured tasks
- Available on mlx-community (Hugging Face)
- Swama has it as a default alias: `swama run qwen3`

**Fallback: Qwen3-1.7B-Instruct (4-bit quantized)**
- If 8B is too slow on base M1 8GB machines
- ~1.0 GB — minimal memory footprint
- May need more careful prompting to avoid overcorrection
- Good enough for grammar-only mode

**Not recommended for MVP:**
- Mistral-7B: would need fine-tuning to match Qwen3-8B out-of-box for rewriting
- Llama-3.2-3B: decent but Qwen3-1.7B beats it at half the size
- GECToR: Python/PyTorch dependency, overkill for MVP

## Prompt Strategy (Critical)

The research is clear: **prompt engineering matters more than model selection for grammar correction quality.** The main risk is overcorrection.

### Anti-Overcorrection Prompt Template

```
System: You are a text editor. You {mode_instruction}.

RULES — follow these exactly:
1. Return ONLY the corrected/rewritten text. No explanations, no preamble, no markdown.
2. Do NOT add information that wasn't in the original.
3. Do NOT remove sentences unless the mode is "Concise".
4. Preserve all proper nouns, technical terms, URLs, and @mentions exactly.
5. Preserve the original paragraph/line break structure.
6. If the text is already good, return it unchanged.
7. Keep the same approximate length (±20%) unless mode is "Concise".
```

### Mode-Specific Instructions

```
Grammar Only: "fix ONLY grammar, spelling, and punctuation errors. Do not change word choice, tone, or sentence structure."

Concise: "make the text shorter and tighter. Remove filler words, redundancy, and unnecessary qualifiers. Keep the core meaning."

Casual: "rewrite in a casual, friendly tone. Make it sound natural and conversational."

Professional: "rewrite in a polished, professional tone. Make it clear, well-structured, and appropriate for business communication."
```

## Latency Expectations

Based on MLX benchmarks on Apple Silicon:

| Model | M1 8GB | M1 Pro 16GB | M3 Pro 18GB |
|-------|--------|-------------|-------------|
| Qwen3-1.7B (4-bit) | ~80 tok/s | ~100 tok/s | ~120 tok/s |
| Qwen3-8B (4-bit) | ~30 tok/s | ~50 tok/s | ~80 tok/s |

For a typical paragraph (50-100 words output), this means:
- Qwen3-1.7B: **0.5–1.5 seconds** ← instant feel
- Qwen3-8B: **1–3 seconds** ← acceptable, might need a progress indicator

Both hit our < 3 second target for paragraph-length text.

## Next Steps

1. Install Swama on your Mac
2. Pull Qwen3-8B: `swama pull qwen3`
3. Test rewrite quality with our four mode prompts against 10 sample texts
4. If quality is good → wire Swama API into the menu bar app
5. If quality needs work → try Qwen3-1.7B or adjust prompts
