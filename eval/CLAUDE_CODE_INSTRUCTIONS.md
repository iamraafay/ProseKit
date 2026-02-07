# Claude Code: Prompt Evaluation Execution Plan

You are running the ProseKit grammar prompt evaluation harness. This directory
contains a Python test suite that sends grammar-error sentences through prompt
variants via Swama's OpenAI-compatible API and scores the outputs.

## Prerequisites

1. Swama must be running with Qwen3-8B loaded. Swama runs on port **28100** by
   default. Verify:
   ```bash
   curl -s http://localhost:28100/v1/models | head -5
   ```
   If that fails, open Swama.app from `/Applications/Swama.app` and load
   `mlx-community/Qwen3-8B-4bit`. Wait until the model is fully loaded before
   proceeding.

2. Install Python dependencies in a venv (system Python may be too old):
   ```bash
   cd eval
   python3.13 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

3. All `eval_prompts.py` and `quick_test.py` commands need the Swama URL flag:
   ```
   --url http://localhost:28100
   ```

## Step 1: Smoke Test (built-in samples, ~5 min)

Run the evaluation against the 31 built-in hand-curated samples first.
This requires no downloads and will confirm everything works:

```bash
cd eval
source .venv/bin/activate
python eval_prompts.py --builtin --show-all --output results_builtin.json --url http://localhost:28100
```

**What to look for in the output:**
- A comparison table ranking all variants by GLEU score
- Zero errors (all 31 samples should process)
- Average latency should be 1-2 seconds per sample
- The "already correct" samples (indices 18-20) should be returned unchanged
  by good variants

**If errors occur:**
- `ConnectionError` → Swama is not running or wrong port (default is 28100)
- `Timeout` → Model may still be loading, wait and retry
- Garbled output → Check that `mlx-community/Qwen3-8B-4bit` is the loaded model

## Step 2: Full JFLEG Evaluation (~15-20 min)

Once the smoke test passes, run against 100 JFLEG samples:

```bash
python eval_prompts.py --samples 100 --output results_jfleg.json --url http://localhost:28100
```

This downloads the JFLEG test set from HuggingFace on first run (~2MB).

## Step 3: Analyze Results

After both runs complete, analyze `results_jfleg.json` to understand:

1. **Which variant wins?** Look at the comparison table. Higher GLEU = better.
2. **Overcorrection patterns** — Which variant changes the least unnecessarily?
3. **Failure cases** — Search the JSON for samples where GLEU < 0.3. These are
   the ones the model is struggling with.

Print a summary:
```bash
python -c "
import json
with open('results_jfleg.json') as f:
    data = json.load(f)
for r in data['results']:
    m = r['metrics']
    print(f\"{m['variant']:25s}  GLEU={m['avg_gleu']:.4f}  Exact={m['exact_match_rate']:.1%}  Overcorr={m['avg_overcorrection']:.4f}  Latency={m['avg_latency']:.1f}s\")
print()
# Find worst-performing samples for the best variant
best = sorted(data['results'], key=lambda r: r['metrics']['avg_gleu'], reverse=True)[0]
bad = [d for d in best['details'] if d.get('gleu', 1) < 0.3 and not d.get('error')]
print(f'Worst samples for {best[\"metrics\"][\"variant\"]} ({len(bad)} with GLEU < 0.3):')
for d in bad[:10]:
    print(f\"  Source:  {d['source']}\")
    print(f\"  Output:  {d['output']}\")
    print(f\"  Ref[0]:  {d['references'][0]}\")
    print(f\"  GLEU:    {d['gleu']:.4f}\")
    print()
"
```

## Step 4: Iterate on Prompts

Based on the failure patterns from Step 3, edit `prompts.py` to create new
variants (V6, V7, etc.). Common issues to address:

- **Model adds explanations** → Strengthen "output ONLY corrected text" rule
- **Model over-corrects style** → Add "do NOT improve writing style" rule
- **Model misses obvious errors** → Try lower temperature or few-shot examples
- **Model rewrites instead of fixing** → Add "change as few words as possible"
- **Model returns unchanged when it shouldn't** → Make instruction more direct

After editing `prompts.py`, re-run:
```bash
python eval_prompts.py --builtin --output results_v2.json --url http://localhost:28100
```

Repeat until you find a variant that:
- GLEU > 0.6 on JFLEG
- Overcorrection < 0.1
- Returns already-correct text unchanged
- Latency < 4s average

## Step 5: Quick-Test Edge Cases

Use `quick_test.py` to verify the winning variant on tricky inputs:

```bash
# Homophones
python quick_test.py --url http://localhost:28100 "Their going to there house with you're friends"

# Already correct (should be unchanged)
python quick_test.py --url http://localhost:28100 "The weather is beautiful today."

# Chat-style messages (ProseKit's primary use case)
python quick_test.py --url http://localhost:28100 "hey can u send me the file i need it asap thx"

# Technical writing
python quick_test.py --url http://localhost:28100 "The API endpoint returns a JSON object which contain the users data"

# Mixed errors
python quick_test.py --url http://localhost:28100 "I should of went to the docter but I didnt had no time"

# Question that looks like a question (should NOT be answered, just corrected)
python quick_test.py --url http://localhost:28100 "Is this even god?"

# Long text
python quick_test.py --url http://localhost:28100 "Me and him goes to the libary every tuesdays to studie for are exam and we usally stay their for about three hours becuse we have alot of material to cover"
```

## Step 6: Update Production Prompt

Once you identify the best variant, update `ProseKit/Sources/RewriteMode.swift`
with the winning prompt. The grammar mode now has its own dedicated prompt in the
`systemPrompt` computed property (separate from the shared template used by
concise/casual/professional modes).

Key places to update:
- The `case .grammar:` branch in `systemPrompt` — the full prompt text
- `temperature` (line ~52) — if the winning variant uses a different temp

## File Reference

| File | Purpose |
|------|---------|
| `prompts.py` | All prompt variants — **edit this to iterate** |
| `eval_prompts.py` | Main eval harness (run this) |
| `quick_test.py` | Single-sentence tester |
| `builtin_samples.py` | 31 hand-curated test cases |
| `requirements.txt` | Python deps |
| `results_builtin.json` | Output from Step 1 (V1-V5) |
| `results_jfleg.json` | Output from Step 2 (V1-V5) |
| `results_v2.json` | Builtin results for iteration 2 (V2, V6-V8) |
| `results_jfleg_v2.json` | JFLEG results for iteration 2 (V2, V6-V8) |

---

## Evaluation Findings (2026-02-07)

### Variants Tested

Eight prompt variants were evaluated across two rounds:

| Variant | Strategy | Temp |
|---------|----------|------|
| v1_production | Original template prompt ("You are a text editor...") | 0.3 |
| v2_strict_minimal | Strict rules, "absolute minimum changes" | 0.2 |
| v3_few_shot | Few-shot examples in prompt | 0.2 |
| v4_copy_editor | Role-play as copy editor | 0.3 |
| v5_minimal_instruction | Ultra-concise single-sentence instruction | 0.3 |
| v6_strict_with_examples | v2 + spelling emphasis + examples of minimal fixes | 0.2 |
| v7_surgical | Ultra-strict "fix ONLY clear errors" | 0.1 |
| v8_minimal_diff | "Smallest possible diff" framing | 0.2 |

### Round 1 Results — JFLEG 100 samples (V1-V5)

| Variant | GLEU | Exact Match | Change Rate | Overcorrection | Latency |
|---------|------|-------------|-------------|----------------|---------|
| v5_minimal_instruction | 0.5791 | 0.0% | 99.0% | 0.4157 | 1.02s |
| v1_production | 0.5715 | 0.0% | 97.0% | 0.3865 | 1.55s |
| v2_strict_minimal | 0.6701 | 15.0% | 67.0% | 0.1509 | 1.41s |
| v3_few_shot | 0.5662 | 0.0% | 99.0% | 0.4078 | 1.39s |
| v4_copy_editor | 0.5577 | 0.0% | 100.0% | 0.4338 | 1.48s |

**Key finding:** V1 (production) had 0% exact match and 39% overcorrection — it
was rewriting almost everything. V2 was significantly better with 15% exact match
and only 15% overcorrection.

### Failure Pattern Analysis

The main problems across all V1-V5 variants:
1. **Whitespace normalization** — model collapses ` , ` to `, ` and ` .` to `.`,
   which JFLEG's tokenized references penalize heavily
2. **Over-eager rephrasing** — model restructures correct-but-awkward sentences
3. **Missed misspellings** — V2 left "misundrestood" and "acticle" uncorrected
4. **Hallucinated corrections** — "They were drove" → "They were driving" (wrong)

### Round 2 Results — JFLEG 100 samples (V6-V8 + V2 baseline)

| Variant | GLEU | Exact Match | Change Rate | Overcorrection | Latency |
|---------|------|-------------|-------------|----------------|---------|
| **v8_minimal_diff** | **0.7364** | 14.0% | 55.0% | **0.0668** | 1.28s |
| v7_surgical | 0.7069 | 14.0% | 72.0% | 0.1281 | 1.25s |
| v2_strict_minimal | 0.6685 | 15.0% | 67.0% | 0.1603 | 1.77s |
| v6_strict_with_examples | 0.6564 | 9.0% | 78.0% | 0.1985 | 1.70s |

### Winner: v8_minimal_diff

**v8_minimal_diff** won decisively:
- **Highest GLEU** (0.7364) — 10% better than v2 baseline
- **Lowest overcorrection** (0.0668) — 6x better than v1 production
- **Lowest change rate** (55%) — most conservative, fewest unnecessary edits
- **Fast** (1.28s avg, 1.66s P95)

The "smallest possible diff" framing was the key insight — it aligned the model's
objective with the actual goal better than listing rules about what not to change.

### Edge Case Results (quick_test.py)

| Test Case | Result |
|-----------|--------|
| Homophones ("Their going to there house...") | Correctly fixed all three |
| Already correct ("The weather is beautiful today.") | Returned unchanged |
| Chat-style ("hey can u send me...") | Preserved informal style, added punctuation |
| Technical ("The API endpoint...") | Fixed "contain" → "contains", "users" → "user's" |
| Mixed errors ("I should of went...") | Fixed all: "of" → "have", "went" → "gone", "docter" → "doctor" |
| Ambiguous ("Is this even god?") | Returned unchanged (did not hallucinate "good") |
| Long mixed ("Me and him goes to the libary...") | Fixed spelling and grammar throughout |

### Production Update

The winning v8_minimal_diff prompt was applied to `ProseKit/Sources/RewriteMode.swift`:
- Grammar mode temperature changed from 0.3 → 0.2
- Grammar mode now uses a dedicated prompt (separate from the shared template)
- Other modes (concise, casual, professional) unchanged
