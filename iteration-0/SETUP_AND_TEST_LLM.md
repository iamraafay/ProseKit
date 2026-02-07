# Instructions for Claude Code: Install Swama & Test LLM Quality

These are instructions for Claude Code to follow. Execute each section in order. Stop and report results after the test suite.

## 1. Install Swama

```bash
brew install swama
```

If Homebrew is not installed, install it first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Verify Swama installed:
```bash
swama --version
```

## 2. Pull the Model

Pull Qwen3-8B (4-bit quantized, ~4.3 GB):
```bash
swama pull qwen3
```

This may take a few minutes depending on internet speed. Wait for it to complete.

## 3. Quick Sanity Check

Run a quick test to make sure the model responds:
```bash
swama run qwen3 "Fix the grammar: me and him went to store yesterday and buyed some foods"
```

Expected: something like "He and I went to the store yesterday and bought some food."

If this works, proceed to the test suite.

## 4. Start Swama Server

Start the local API server (keep it running in background):
```bash
swama serve --port 28100 &
```

Wait a few seconds, then verify it's up:
```bash
curl -s http://localhost:28100/v1/models | head -20
```

## 5. Run the Test Suite

Create and run this Python script. It tests all four rewrite modes against 10 sample texts and saves results to `~/Projects/GrammarlyReplacement/iteration-0/llm_test_results.md`.

```python
#!/usr/bin/env python3
"""ProseKit LLM Quality Test Suite — Tests four rewrite modes against sample texts via Swama API."""

import json
import urllib.request
import time
import os

API_URL = "http://localhost:28100/v1/chat/completions"
MODEL = "mlx-community/Qwen3-8B-Instruct-4bit"  # Swama's default qwen3 alias
OUTPUT_FILE = os.path.expanduser("~/Projects/GrammarlyReplacement/iteration-0/llm_test_results.md")

# ─── Mode Prompts ───────────────────────────────────────────

MODES = {
    "grammar": "Fix ONLY grammar, spelling, and punctuation errors. Do not change word choice, tone, or sentence structure.",
    "concise": "Make the text shorter and tighter. Remove filler words, redundancy, and unnecessary qualifiers. Keep the core meaning.",
    "casual": "Rewrite in a casual, friendly tone. Make it sound natural and conversational.",
    "professional": "Rewrite in a polished, professional tone. Make it clear, well-structured, and appropriate for business communication."
}

SYSTEM_TEMPLATE = """You are a text editor. You {mode_instruction}.

RULES — follow these exactly:
1. Return ONLY the corrected/rewritten text. No explanations, no preamble, no markdown.
2. Do NOT add information that wasn't in the original.
3. Do NOT remove sentences unless the mode is "Concise".
4. Preserve all proper nouns, technical terms, URLs, and @mentions exactly.
5. Preserve the original paragraph/line break structure.
6. If the text is already good, return it unchanged.
7. Keep the same approximate length (±20%) unless mode is "Concise".
8. Do NOT wrap your response in quotes."""

# ─── Sample Texts ───────────────────────────────────────────

SAMPLES = [
    {
        "id": 1,
        "label": "Slack message with typos",
        "text": "hey can u take a look at the PR when u get a chance? i think theres a bug in the auth flow where its not redirecting properly after login. also the tests are failing on CI but i think its unrelated"
    },
    {
        "id": 2,
        "label": "Email with grammar errors",
        "text": "Hi John, I wanted to follow up on our meeting from yesterday. Me and the team has been working on the proposal and we think their are some areas where we could improved. I would appreciate if you could review it and let me know you're thoughts by Friday."
    },
    {
        "id": 3,
        "label": "PR description (rough notes)",
        "text": "added retry logic for API calls. before this if the call failed it would just crash. now it retries 3 times with exponential backoff. also fixed the bug where the timeout wasnt being respected. changed the default timeout from 30s to 10s because 30 was too long and users were complaining"
    },
    {
        "id": 4,
        "label": "iMessage (very casual)",
        "text": "yo did u see what happened at the meeting today?? mike basically said the whole project is getting scrapped lol. im kinda stressed about it ngl. wanna grab coffee tmrw and talk about it?"
    },
    {
        "id": 5,
        "label": "Non-native English speaker",
        "text": "I am writing to inform you that the delivery of the goods will be delay by approximately 2 weeks due to supply chain issue. We are very sorry for the inconvenient and we will do our best to expedite the process. Please do not hesitate to contact me if you have any question."
    },
    {
        "id": 6,
        "label": "Already well-written (should not overcorrect)",
        "text": "The new authentication system uses JWT tokens with a 24-hour expiry window. When a token expires, the client automatically refreshes it using the stored refresh token. If the refresh token has also expired, the user is redirected to the login page."
    },
    {
        "id": 7,
        "label": "Long rambling text",
        "text": "So basically what I was thinking is that we should probably maybe consider looking into the possibility of potentially restructuring the way we handle the onboarding flow because right now it's kind of confusing for new users and I've been hearing from a lot of people that they don't really understand what they're supposed to do after they sign up and I think if we simplified it a bit it would really help with our retention numbers which have been kind of going down lately."
    },
    {
        "id": 8,
        "label": "Technical with special terms",
        "text": "the kubectl apply -f deployment.yaml command is failing with a OOMKilled error. i think we need to bump the memory limits in the pod spec. currently its set to 512Mi but the container is using like 800Mi at peak. @sarah can you check the grafana dashboard for the exact numbers?"
    },
    {
        "id": 9,
        "label": "Mixed languages / proper nouns",
        "text": "We need to update the README.md for the ProseKit repo. Also @raafay mentioned that the API endpoint at https://api.example.com/v2/rewrite needs to be documented. The François Müller branch has the latest changes."
    },
    {
        "id": 10,
        "label": "Very short message",
        "text": "sounds good, lets do it tmrw"
    }
]

# ─── API Call ───────────────────────────────────────────────

def rewrite(text, mode_name):
    system_prompt = SYSTEM_TEMPLATE.format(mode_instruction=MODES[mode_name])

    payload = json.dumps({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ],
        "temperature": 0.3,
        "max_tokens": 1024
    }).encode("utf-8")

    req = urllib.request.Request(API_URL, data=payload, headers={"Content-Type": "application/json"})

    try:
        start = time.time()
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode())
            elapsed = time.time() - start
            content = result["choices"][0]["message"]["content"].strip()
            return content, round(elapsed, 2)
    except Exception as e:
        return f"ERROR: {e}", 0


# ─── Main ───────────────────────────────────────────────────

def main():
    print("ProseKit LLM Quality Test Suite")
    print("=" * 50)
    print(f"Model: {MODEL}")
    print(f"API: {API_URL}")
    print()

    results = []
    results.append("# ProseKit LLM Quality Test Results\n")
    results.append(f"**Model:** {MODEL}\n")
    results.append(f"**Date:** {time.strftime('%Y-%m-%d %H:%M')}\n")
    results.append("")

    for sample in SAMPLES:
        print(f"\n--- Sample {sample['id']}: {sample['label']} ---")
        results.append(f"## Sample {sample['id']}: {sample['label']}\n")
        results.append(f"**Original:**\n> {sample['text']}\n")

        for mode_name in MODES:
            print(f"  Testing mode: {mode_name}...", end=" ", flush=True)
            output, elapsed = rewrite(sample['text'], mode_name)
            print(f"({elapsed}s)")

            results.append(f"### {mode_name.capitalize()} ({elapsed}s)\n")
            results.append(f"> {output}\n")

        results.append("---\n")

    # Write results
    with open(OUTPUT_FILE, "w") as f:
        f.write("\n".join(results))

    print(f"\nResults saved to: {OUTPUT_FILE}")
    print("Done.")

if __name__ == "__main__":
    main()
```

Save this script to `~/Projects/GrammarlyReplacement/iteration-0/test_llm_quality.py` and run it:
```bash
python3 ~/Projects/GrammarlyReplacement/iteration-0/test_llm_quality.py
```

## 6. Report Results

After the test suite completes, the results will be at:
```
~/Projects/GrammarlyReplacement/iteration-0/llm_test_results.md
```

Read the file and report a summary:
- Which modes produced good output?
- Any overcorrection (changed text that was already correct)?
- Did it preserve proper nouns, URLs, @mentions?
- Was the "already well-written" sample (Sample 6) left mostly unchanged?
- Latency per rewrite?

## Troubleshooting

If `swama serve` fails, try:
```bash
# Check if port is already in use
lsof -i :28100

# Try a different port
swama serve --port 28200
```

If the model name doesn't match, list available models:
```bash
swama list
curl -s http://localhost:28100/v1/models
```

Then update the MODEL variable in the Python script to match.

If Qwen3-8B is too slow or causes memory issues on your Mac, try the smaller model:
```bash
swama pull qwen3:1.7b
```

And update MODEL in the script accordingly.

---

## 7. Findings (2026-02-06)

**Environment:** Swama v2.0.1, Model `mlx-community/Qwen3-8B-4bit` (4.3 GB), Apple Silicon Mac

### Setup Notes

- Homebrew was installed at `/opt/homebrew/bin/brew` but not in the default shell `$PATH`. The `brew install swama` command installs a macOS `.app` bundle.
- The `swama` CLI binary lives at `/Applications/Swama.app/Contents/Helpers/swama-bin`, not on `$PATH` by default.
- The model ID reported by the server is `mlx-community/Qwen3-8B-4bit` (not `Qwen3-8B-Instruct-4bit` as specified in the original script). The `MODEL` variable in the test script was updated to match.

### Critical Issue: `<think>` Tags in Every Response

The Qwen3-8B model emits chain-of-thought `<think>...</think>` blocks in **100% of responses**. This reasoning text appears before the actual rewritten output. In **5 out of 40 calls (12.5%)**, the thinking consumed the entire token budget and **no usable output was produced at all**.

This is the single biggest blocker for production use. The thinking must either be disabled at the model/API level or stripped in post-processing, and a retry mechanism is needed for the truncation failures.

### Quality by Mode

| Mode | Rating | Notes |
|------|--------|-------|
| **Grammar** | Acceptable, inconsistent | Catches most errors (`u`->`you`, `theres`->`there's`, `their`->`there`). Misses some capitalization and pronoun corrections ("Me and the team" not fixed). |
| **Concise** | Good when it works | Effective at trimming filler (Sample 7: 80+ words down to ~30). 2 outputs truncated with no result. |
| **Casual** | Mixed | Good tone when produced. Gets stuck in reasoning loops on already-casual text (2 failures on Samples 4 and 10). |
| **Professional** | Strongest mode | Clean business rewrites. Occasionally overcorrects already-good text (expanded "JWT" to "JSON Web Tokens"). |

### Overcorrection (Sample 6 — Already Well-Written)

- **Grammar:** Returned unchanged. Correct.
- **Concise:** Minor reasonable trims. Acceptable.
- **Casual:** Added a preamble ("Here's how...") not in the original. Overcorrected.
- **Professional:** Swapped "uses" for "utilizes" and expanded acronyms. Overcorrected.

### Proper Noun / Special Term Preservation

Generally strong. `kubectl`, `deployment.yaml`, `@sarah`, `@raafay`, `README.md`, `https://api.example.com/v2/rewrite`, `François Müller` (with unicode), `ProseKit`, `OOMKilled`, `512Mi`/`800Mi` all preserved correctly. Minor issues: inconsistent capitalization of `Grafana` in some modes; `JWT` expanded in Professional mode.

### Latency

| Metric | Value |
|--------|-------|
| Average | **15.2 seconds** |
| Minimum | 6.7s (Sample 10 Concise) |
| Maximum | 29.2s (Sample 3 Concise — failed output) |
| Median | ~12.8s |

The 27-29s outliers all correlate with truncated/failed outputs where the model's reasoning loop exhausted the token budget.

### Verdict

**Not suitable for real-time use in current configuration.** Three blockers:

1. **`<think>` tags** — 100% of responses contain them. Investigate `enable_thinking=false` or `<|/no_think|>` special token to disable chain-of-thought.
2. **12.5% failure rate** — 5/40 calls produced no usable output. Need retry logic or thinking-disabled mode.
3. **15s average latency** — 5-10x too slow for an inline writing tool (target: <2s). The bulk of generation time is spent on reasoning the user never sees.

### Recommended Next Steps

Re-run the test suite with thinking disabled. See Section 8 below.

---

## 8. Instructions for Claude Code: Re-Run with Thinking Disabled

The `<think>` tags are causing 15s latency and 12.5% failure rate. There are two ways to disable Qwen3's thinking mode. Try them in order.

### Method A: `/no_think` Soft Switch in System Prompt

This is a built-in Qwen3 feature. Append `/no_think` to the end of the system prompt. This tells the model to skip chain-of-thought reasoning.

Update the test script's `SYSTEM_TEMPLATE` to append `/no_think` at the very end:

```python
SYSTEM_TEMPLATE = """You are a text editor. You {mode_instruction}.

RULES — follow these exactly:
1. Return ONLY the corrected/rewritten text. No explanations, no preamble, no markdown.
2. Do NOT add information that wasn't in the original.
3. Do NOT remove sentences unless the mode is "Concise".
4. Preserve all proper nouns, technical terms, URLs, and @mentions exactly.
5. Preserve the original paragraph/line break structure.
6. If the text is already good, return it unchanged.
7. Keep the same approximate length (±20%) unless mode is "Concise".
8. Do NOT wrap your response in quotes.

/no_think"""
```

Also increase `max_tokens` to 2048 and set these recommended parameters for non-thinking mode:
```python
"temperature": 0.7,
"top_p": 0.8,
"max_tokens": 2048
```

### Method B: `chat_template_kwargs` API Parameter

If Method A doesn't work, try passing `enable_thinking: false` via the API. Add this to the request payload:

```python
payload = json.dumps({
    "model": MODEL,
    "messages": [...],
    "temperature": 0.7,
    "top_p": 0.8,
    "max_tokens": 2048,
    "chat_template_kwargs": {"enable_thinking": False}
}).encode("utf-8")
```

Note: This depends on Swama passing the parameter through to the chat template. If Swama ignores it, Method A is the fallback.

### Method C: Post-Processing Fallback

If neither Method A nor B fully eliminates thinking, add post-processing to strip `<think>` tags:

```python
import re

def strip_thinking(text):
    """Remove <think>...</think> blocks from model output."""
    cleaned = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    return cleaned if cleaned else None  # None means thinking consumed entire output
```

If `strip_thinking` returns None, retry the request (up to 2 retries).

### What to Report

After re-running with thinking disabled, report:
1. Are `<think>` tags still appearing? (check raw output)
2. New average latency (target: < 3 seconds for a paragraph)
3. Failure rate (target: 0%)
4. Output quality — same 10 samples, all 4 modes
5. Save results to `~/Projects/GrammarlyReplacement/iteration-0/llm_test_results_v2.md`

---

## 9. V2 Findings (2026-02-06) — With `/no_think` Enabled

**Method used:** Method A — appended `/no_think` to the end of the system prompt. Also set `temperature: 0.7`, `top_p: 0.8`, `max_tokens: 2048`. Added `strip_thinking` post-processing fallback with retry logic (Method C), though it was never triggered.

### 1. `<think>` Tags

**Completely eliminated.** Zero `<think>` blocks appeared in any of the 40 outputs. The `/no_think` soft switch worked perfectly. The strip_thinking fallback and retry logic were never triggered.

### 2. Latency

| Metric | V1 (with thinking) | V2 (no_think) | Improvement |
|--------|-------------------|---------------|-------------|
| Average | 15.2s | **2.65s** | **5.7x faster** |
| Minimum | 6.7s | **1.42s** | 4.7x faster |
| Maximum | 29.2s | **4.75s** | 6.1x faster |
| Median | ~12.8s | **~2.6s** | 4.9x faster |

All 40 rewrites completed in under 5 seconds. Short messages (Sample 10) complete in ~1.4s. Longer texts (Sample 7, 8) take 3-4s. This is within the target range of < 3s for most inputs.

### 3. Failure Rate

**0% failures.** All 40 calls produced clean, usable output. No retries needed. Down from 12.5% in V1.

### 4. Output Quality by Mode

**Grammar:**
- Improved on some fronts but more conservative overall. Fixed contractions (`theres` → `there's`, `its` → `it's`, `wasnt` → `wasn't`) and spelling (`inconvenient` → `inconvenience`).
- Still misses capitalization at sentence starts (Samples 1, 3, 8 left lowercase). Still misses "Me and the team" → "The team and I" (Sample 2). Missed `delay` → `delayed` but caught other verb errors.
- Sample 1 Grammar was returned **completely unchanged** — missed all corrections. This is a regression from V1.
- Overall: more conservative than V1 grammar mode. Fewer corrections applied.

**Concise:**
- Much improved reliability (0% failures vs 2 failures in V1).
- Sample 7 (long rambling text) was excellently condensed from 80+ words to ~40 focused words.
- Sample 3 (PR notes) received proper capitalization and tightening.
- Interestingly, some "Concise" outputs also applied grammar fixes (capitalization, contractions) that Grammar mode missed.

**Casual:**
- Now produces output reliably (0% failures vs 2 failures in V1).
- Very conservative — Samples 4 and 8 were returned nearly unchanged, correctly recognizing they were already casual.
- Sample 9 (proper nouns) returned completely unchanged — correct behavior since it was already well-written.

**Professional:**
- Still the strongest mode. Properly capitalized sentences, added appropriate punctuation, removed slang.
- Sample 8: Added backtick formatting around `kubectl apply -f deployment.yaml` — a nice touch for technical contexts but technically adds markdown (violates rule 1).
- No longer overcorrects Sample 6 (JWT text) — returned unchanged. Major improvement over V1.
- Sample 4 (iMessage): appropriately removed "yo" and "lol" but kept "kinda" and "NGL" — could be more thorough.

### 5. Overcorrection (Sample 6 — Already Well-Written)

| Mode | V1 | V2 |
|------|----|----|
| Grammar | Unchanged ✅ | Unchanged ✅ |
| Concise | Minor trims | Minor trims (removed "also", "window") ✅ |
| Casual | Added preamble ❌ | Minor rephrasing only ✅ |
| Professional | Over-expanded ❌ | Unchanged ✅ |

Significant improvement — Casual and Professional no longer overcorrect well-written text.

### 6. Proper Noun / Special Term Preservation

All preserved correctly across all modes: `kubectl`, `deployment.yaml`, `@sarah`, `@raafay`, `README.md`, `https://api.example.com/v2/rewrite`, `François Müller`, `ProseKit`, `OOMKilled`, `512Mi`/`800Mi`, `JWT`. Sample 9 was returned unchanged across all 4 modes — perfect preservation.

### 7. Overall Assessment

The `/no_think` switch transforms Qwen3-8B from unusable to viable:

| Metric | V1 | V2 | Target | Met? |
|--------|----|----|--------|------|
| `<think>` tags | 100% of responses | 0% | 0% | ✅ |
| Failure rate | 12.5% | 0% | 0% | ✅ |
| Avg latency | 15.2s | 2.65s | < 3s | ✅ |
| Overcorrection | Frequent | Rare | Minimal | ✅ |

**Remaining concerns:**
- Grammar mode is too conservative — returned Sample 1 completely unchanged and still misses capitalization and pronoun corrections. May need prompt tuning or a grammar-specific system prompt revision.
- Professional mode could be more thorough with slang removal (kept "kinda", "NGL" in Sample 4).
- The `temperature: 0.7` setting may be contributing to conservative behavior in Grammar mode — worth testing `0.3` for Grammar specifically while keeping `0.7` for other modes.
