#!/usr/bin/env python3
"""
eval_styles.py — ProseKit Style Mode Evaluation Harness

Evaluates Concise, Casual, and Professional prompt variants against
hand-curated test samples. Uses mode-specific metrics since style
transformation is different from grammar correction.

Usage:
    # Evaluate all modes:
    python eval_styles.py --url http://localhost:28100

    # Evaluate a single mode:
    python eval_styles.py --mode concise --url http://localhost:28100

    # Save results:
    python eval_styles.py --output style_results.json --url http://localhost:28100

    # Verbose output:
    python eval_styles.py --show-all --url http://localhost:28100

Metrics (per mode):
    Concise:
      - Compression: word count reduction ratio (higher = more trimming)
      - Meaning Preserved: % of key terms retained in output
      - GLEU: n-gram overlap with references
      - No-bloat: penalizes output longer than input

    Casual:
      - Informality Score: contraction usage, simple word ratio
      - Meaning Preserved: % of key terms retained
      - GLEU: n-gram overlap with references
      - Already-casual Stability: unchanged when input is already casual

    Professional:
      - Formality Score: absence of slang, proper structure
      - Meaning Preserved: % of key terms retained
      - GLEU: n-gram overlap with references
      - Already-professional Stability: unchanged when input is already formal
"""

import argparse
import json
import re
import sys
import time
from collections import Counter

import requests


# ─── Shared Metrics ──────────────────────────────────────────────────────────

def get_ngrams(tokens, n):
    return [tuple(tokens[i:i+n]) for i in range(len(tokens) - n + 1)]

def compute_gleu_sentence(source_tokens, output_tokens, reference_tokens, max_n=4):
    import math
    if not output_tokens or not reference_tokens:
        return 0.0
    scores = []
    for n in range(1, min(max_n + 1, len(output_tokens) + 1)):
        output_ngrams = Counter(get_ngrams(output_tokens, n))
        reference_ngrams = Counter(get_ngrams(reference_tokens, n))
        matches = sum((output_ngrams & reference_ngrams).values())
        total = sum(output_ngrams.values())
        scores.append(matches / total if total > 0 else 0.0)
    if not scores or all(s == 0 for s in scores):
        return 0.0
    log_scores = [math.log(s) if s > 0 else -float('inf') for s in scores]
    avg_log = sum(log_scores) / len(log_scores)
    if avg_log == -float('inf'):
        return 0.0
    bp = 1.0
    if len(output_tokens) < len(reference_tokens):
        bp = math.exp(1 - len(reference_tokens) / max(len(output_tokens), 1))
    return bp * math.exp(avg_log)

def compute_gleu(source, output, references):
    source_tokens = source.lower().split()
    output_tokens = output.lower().split()
    best = 0.0
    for ref in references:
        ref_tokens = ref.lower().split()
        score = compute_gleu_sentence(source_tokens, output_tokens, ref_tokens)
        best = max(best, score)
    return best

def meaning_preserved(output, preserve_terms):
    """Check what fraction of required key terms appear in the output."""
    if not preserve_terms:
        return 1.0
    output_lower = output.lower()
    found = sum(1 for term in preserve_terms if term.lower() in output_lower)
    return found / len(preserve_terms)


# ─── Concise-Specific Metrics ────────────────────────────────────────────────

def compression_ratio(source, output):
    """Word count reduction. 1.0 = same length, 0.5 = half the words."""
    src_words = len(source.split())
    out_words = len(output.split())
    if src_words == 0:
        return 1.0
    return out_words / src_words

def is_bloated(source, output):
    """True if output is longer than source (bad for concise mode)."""
    return len(output.split()) > len(source.split())


# ─── Casual-Specific Metrics ─────────────────────────────────────────────────

CONTRACTIONS = [
    "don't", "doesn't", "didn't", "won't", "wouldn't", "can't", "couldn't",
    "shouldn't", "isn't", "aren't", "wasn't", "weren't", "I'm", "I've",
    "I'll", "I'd", "we're", "we've", "we'll", "we'd", "you're", "you've",
    "you'll", "you'd", "they're", "they've", "they'll", "they'd", "it's",
    "that's", "there's", "here's", "what's", "who's", "let's", "he's",
    "she's", "hasn't", "haven't",
]

CASUAL_MARKERS = [
    "hey", "hi", "just", "pretty", "kinda", "gonna", "wanna", "gotta",
    "yeah", "yep", "nope", "cool", "awesome", "great", "nice", "btw",
    "fyi", "tbh", "imo", "lol", "haha", "!", "so ", "basically",
]

def informality_score(text):
    """Score 0-1 measuring how casual/informal the text sounds."""
    text_lower = text.lower()
    words = text_lower.split()
    if not words:
        return 0.0

    score = 0.0
    # Contractions
    contraction_count = sum(1 for w in words if w.rstrip(".,!?;:") in [c.lower() for c in CONTRACTIONS])
    score += min(contraction_count / max(len(words), 1) * 5, 0.4)  # up to 0.4

    # Casual markers
    marker_count = sum(1 for marker in CASUAL_MARKERS if marker in text_lower)
    score += min(marker_count / 10, 0.3)  # up to 0.3

    # Exclamation marks
    if "!" in text:
        score += 0.1

    # Short sentences (avg words per sentence)
    sentences = re.split(r'[.!?]+', text)
    sentences = [s.strip() for s in sentences if s.strip()]
    if sentences:
        avg_sent_len = sum(len(s.split()) for s in sentences) / len(sentences)
        if avg_sent_len < 12:
            score += 0.1

    # Dashes and ellipses (informal punctuation)
    if "—" in text or "..." in text or " - " in text:
        score += 0.1

    return min(score, 1.0)


# ─── Professional-Specific Metrics ───────────────────────────────────────────

SLANG_WORDS = [
    "hey", "yeah", "yep", "nope", "gonna", "wanna", "gotta", "kinda",
    "tbh", "imo", "lol", "haha", "lmao", "ngl", "idk", "prob", "def",
    "pls", "u ", "ur ", "tmrw", "asap", "thx", "btw", "fyi", "rn",
    "like ", "basically", "totally", "super ", "awesome", "cool",
    "tons of", "big time", "crushed", "broke", "stuff",
]

FORMAL_MARKERS = [
    "please", "regarding", "pursuant", "appreciate", "ensure",
    "accordingly", "furthermore", "however", "therefore", "consequently",
    "demonstrate", "implement", "facilitate", "assessment", "initiative",
    "comprehensive", "subsequently", "preliminary", "approximately",
]

def formality_score(text):
    """Score 0-1 measuring how formal/professional the text sounds."""
    text_lower = text.lower()
    words = text_lower.split()
    if not words:
        return 0.0

    score = 0.5  # Start neutral

    # Penalize slang
    slang_count = sum(1 for slang in SLANG_WORDS if slang in text_lower)
    score -= min(slang_count * 0.1, 0.4)

    # Reward formal markers
    formal_count = sum(1 for marker in FORMAL_MARKERS if marker in text_lower)
    score += min(formal_count * 0.08, 0.3)

    # Complete sentences (starts with capital, ends with period)
    sentences = re.split(r'[.!?]+', text)
    sentences = [s.strip() for s in sentences if s.strip()]
    if sentences:
        proper_sentences = sum(1 for s in sentences if s[0].isupper())
        score += (proper_sentences / len(sentences)) * 0.15

    # No contractions = more formal
    contraction_count = sum(1 for w in words if w.rstrip(".,!?;:") in [c.lower() for c in CONTRACTIONS])
    if contraction_count == 0 and len(words) > 5:
        score += 0.1

    # Penalize exclamation marks (too casual)
    if "!" in text:
        score -= 0.05

    return max(0.0, min(score, 1.0))


# ─── Swama API Client ────────────────────────────────────────────────────────

def call_swama(prompt, system_prompt, temperature=0.7, base_url="http://localhost:28100"):
    url = f"{base_url}/v1/chat/completions"
    payload = {
        "model": "mlx-community/Qwen3-8B-4bit",
        "messages": [
            {"role": "user", "content": f"{system_prompt}\n\n{prompt}"}
        ],
        "temperature": temperature,
        "max_tokens": 512,
    }
    start = time.time()
    try:
        resp = requests.post(url, json=payload, timeout=60)
        resp.raise_for_status()
    except requests.ConnectionError:
        raise ConnectionError(
            "Cannot connect to Swama. Check it's running on the correct port."
        )
    elapsed = time.time() - start
    data = resp.json()
    text = data["choices"][0]["message"]["content"].strip()
    return text, elapsed

def clean_response(text):
    text = text.strip()
    text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    if (text.startswith('"') and text.endswith('"')) or \
       (text.startswith("'") and text.endswith("'")):
        text = text[1:-1].strip()
    if text.startswith("```"):
        lines = text.split("\n")
        lines = [l for l in lines if not l.startswith("```")]
        text = "\n".join(lines).strip()
    return text


# ─── Evaluation ──────────────────────────────────────────────────────────────

def evaluate_style_variant(variant, samples, mode, base_url):
    """Evaluate a prompt variant with mode-specific metrics."""
    name = variant["name"]
    system_prompt = variant["system_prompt"]
    temperature = variant["temperature"]

    print(f"\n{'='*60}")
    print(f"  Evaluating: {name} ({mode} mode)")
    print(f"{'='*60}")

    results = []
    gleu_scores = []
    meaning_scores = []
    latencies = []
    errors = 0

    # Mode-specific accumulators
    if mode == "concise":
        compression_ratios = []
        bloat_count = 0
    elif mode == "casual":
        informality_scores = []
        stability_tests = 0
        stability_pass = 0
    elif mode == "professional":
        formality_scores_list = []
        stability_tests = 0
        stability_pass = 0

    for i, sample in enumerate(samples):
        source = sample["source"]
        references = sample["references"]
        preserve = sample.get("preserve", [])

        if (i + 1) % 5 == 0 or i == 0:
            print(f"  [{i+1}/{len(samples)}] Processing...")

        try:
            raw_output, latency = call_swama(source, system_prompt, temperature, base_url)
            output = clean_response(raw_output)
            latencies.append(latency)
        except Exception as e:
            print(f"  ERROR on sample {i}: {e}")
            errors += 1
            results.append({"index": i, "source": source, "output": None, "error": str(e)})
            continue

        # Shared metrics
        gleu = compute_gleu(source, output, references)
        gleu_scores.append(gleu)

        meaning = meaning_preserved(output, preserve)
        meaning_scores.append(meaning)

        detail = {
            "index": i,
            "source": source,
            "output": output,
            "references": references,
            "gleu": gleu,
            "meaning_preserved": meaning,
            "latency": latency,
        }

        # Mode-specific metrics
        if mode == "concise":
            cr = compression_ratio(source, output)
            compression_ratios.append(cr)
            bloated = is_bloated(source, output)
            if bloated:
                bloat_count += 1
            detail["compression_ratio"] = cr
            detail["bloated"] = bloated

        elif mode == "casual":
            inf_score = informality_score(output)
            informality_scores.append(inf_score)
            detail["informality_score"] = inf_score

            # Stability test: if references match source, output should too
            if any(ref.strip().lower() == source.strip().lower() for ref in references):
                stability_tests += 1
                if output.strip().lower() == source.strip().lower():
                    stability_pass += 1
                detail["stability_test"] = True
                detail["stability_pass"] = output.strip().lower() == source.strip().lower()

        elif mode == "professional":
            form_score = formality_score(output)
            formality_scores_list.append(form_score)
            detail["formality_score"] = form_score

            if any(ref.strip().lower() == source.strip().lower() for ref in references):
                stability_tests += 1
                if output.strip().lower() == source.strip().lower():
                    stability_pass += 1
                detail["stability_test"] = True
                detail["stability_pass"] = output.strip().lower() == source.strip().lower()

        results.append(detail)

    # Aggregate
    n = len(samples) - errors

    metrics = {
        "variant": name,
        "mode": mode,
        "temperature": temperature,
        "total_samples": len(samples),
        "errors": errors,
        "avg_gleu": sum(gleu_scores) / max(len(gleu_scores), 1),
        "avg_meaning": sum(meaning_scores) / max(len(meaning_scores), 1),
        "avg_latency": sum(latencies) / max(len(latencies), 1),
    }

    if mode == "concise":
        metrics["avg_compression"] = sum(compression_ratios) / max(len(compression_ratios), 1)
        metrics["bloat_rate"] = bloat_count / max(n, 1)
        # Composite score for concise: reward compression + meaning + GLEU, penalize bloat
        metrics["composite"] = (
            metrics["avg_gleu"] * 0.3 +
            metrics["avg_meaning"] * 0.3 +
            (1.0 - metrics["avg_compression"]) * 0.3 +  # lower ratio = more compression = better
            (1.0 - metrics["bloat_rate"]) * 0.1
        )

    elif mode == "casual":
        metrics["avg_informality"] = sum(informality_scores) / max(len(informality_scores), 1)
        metrics["stability"] = stability_pass / max(stability_tests, 1) if stability_tests > 0 else None
        metrics["composite"] = (
            metrics["avg_gleu"] * 0.3 +
            metrics["avg_meaning"] * 0.3 +
            metrics["avg_informality"] * 0.3 +
            (metrics["stability"] or 0.5) * 0.1
        )

    elif mode == "professional":
        metrics["avg_formality"] = sum(formality_scores_list) / max(len(formality_scores_list), 1)
        metrics["stability"] = stability_pass / max(stability_tests, 1) if stability_tests > 0 else None
        metrics["composite"] = (
            metrics["avg_gleu"] * 0.3 +
            metrics["avg_meaning"] * 0.3 +
            metrics["avg_formality"] * 0.3 +
            (metrics["stability"] or 0.5) * 0.1
        )

    # Print summary
    print(f"\n  Results for {name}:")
    print(f"  ├── GLEU:           {metrics['avg_gleu']:.4f}")
    print(f"  ├── Meaning:        {metrics['avg_meaning']:.1%}")

    if mode == "concise":
        print(f"  ├── Compression:    {metrics['avg_compression']:.2f}x ({(1-metrics['avg_compression']):.0%} reduction)")
        print(f"  ├── Bloat rate:     {metrics['bloat_rate']:.1%}")
    elif mode == "casual":
        print(f"  ├── Informality:    {metrics['avg_informality']:.4f}")
        if metrics["stability"] is not None:
            print(f"  ├── Stability:      {metrics['stability']:.1%}")
    elif mode == "professional":
        print(f"  ├── Formality:      {metrics['avg_formality']:.4f}")
        if metrics["stability"] is not None:
            print(f"  ├── Stability:      {metrics['stability']:.1%}")

    print(f"  ├── Composite:      {metrics['composite']:.4f}")
    print(f"  ├── Avg latency:    {metrics['avg_latency']:.2f}s")
    print(f"  └── Errors:         {errors}")

    return {"metrics": metrics, "details": results}


def print_comparison(all_results, mode):
    """Print comparison table for a mode."""
    try:
        from tabulate import tabulate
    except ImportError:
        return

    if mode == "concise":
        headers = ["Variant", "Composite↑", "GLEU↑", "Meaning↑", "Compress", "Bloat↓", "Latency"]
        rows = []
        for r in all_results:
            m = r["metrics"]
            rows.append([
                m["variant"],
                f"{m['composite']:.4f}",
                f"{m['avg_gleu']:.4f}",
                f"{m['avg_meaning']:.1%}",
                f"{m['avg_compression']:.2f}x",
                f"{m['bloat_rate']:.1%}",
                f"{m['avg_latency']:.2f}s",
            ])
    elif mode == "casual":
        headers = ["Variant", "Composite↑", "GLEU↑", "Meaning↑", "Informal↑", "Stable", "Latency"]
        rows = []
        for r in all_results:
            m = r["metrics"]
            rows.append([
                m["variant"],
                f"{m['composite']:.4f}",
                f"{m['avg_gleu']:.4f}",
                f"{m['avg_meaning']:.1%}",
                f"{m['avg_informality']:.4f}",
                f"{m['stability']:.1%}" if m["stability"] is not None else "N/A",
                f"{m['avg_latency']:.2f}s",
            ])
    elif mode == "professional":
        headers = ["Variant", "Composite↑", "GLEU↑", "Meaning↑", "Formal↑", "Stable", "Latency"]
        rows = []
        for r in all_results:
            m = r["metrics"]
            rows.append([
                m["variant"],
                f"{m['composite']:.4f}",
                f"{m['avg_gleu']:.4f}",
                f"{m['avg_meaning']:.1%}",
                f"{m['avg_formality']:.4f}",
                f"{m['stability']:.1%}" if m["stability"] is not None else "N/A",
                f"{m['avg_latency']:.2f}s",
            ])

    rows.sort(key=lambda r: float(r[1]), reverse=True)

    print(f"\n{'='*70}")
    print(f"  {mode.upper()} MODE — COMPARISON (sorted by composite)")
    print(f"{'='*70}")
    print(tabulate(rows, headers=headers, tablefmt="grid"))

    best = rows[0]
    print(f"\n  Winner: {best[0]} (composite: {best[1]})")


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="ProseKit Style Mode Evaluation")
    parser.add_argument("--mode", choices=["concise", "casual", "professional", "all"],
                        default="all", help="Which mode to evaluate")
    parser.add_argument("--url", type=str, default="http://localhost:28100",
                        help="Swama API base URL")
    parser.add_argument("--output", type=str, default=None, help="Save results to JSON")
    parser.add_argument("--show-all", action="store_true", help="Print all samples")
    args = parser.parse_args()

    from style_prompts import CONCISE_VARIANTS, CASUAL_VARIANTS, PROFESSIONAL_VARIANTS
    from style_samples import CONCISE_SAMPLES, CASUAL_SAMPLES, PROFESSIONAL_SAMPLES

    # Test connection
    print("Testing Swama connection...")
    try:
        _, latency = call_swama("Hello", "Respond: Hello", 0.0, args.url)
        print(f"  Connected ({latency:.2f}s)")
    except ConnectionError as e:
        print(f"  {e}")
        sys.exit(1)

    modes_to_run = []
    if args.mode in ("all", "concise"):
        modes_to_run.append(("concise", CONCISE_VARIANTS, CONCISE_SAMPLES))
    if args.mode in ("all", "casual"):
        modes_to_run.append(("casual", CASUAL_VARIANTS, CASUAL_SAMPLES))
    if args.mode in ("all", "professional"):
        modes_to_run.append(("professional", PROFESSIONAL_VARIANTS, PROFESSIONAL_SAMPLES))

    all_mode_results = {}

    for mode_name, variants, samples in modes_to_run:
        print(f"\n{'#'*70}")
        print(f"  MODE: {mode_name.upper()}")
        print(f"  Variants: {len(variants)} | Samples: {len(samples)}")
        print(f"{'#'*70}")

        mode_results = []
        for variant in variants:
            result = evaluate_style_variant(variant, samples, mode_name, args.url)
            mode_results.append(result)

        if len(mode_results) > 1:
            print_comparison(mode_results, mode_name)

        all_mode_results[mode_name] = mode_results

        # Show sample outputs if verbose
        if args.show_all:
            print(f"\n  --- All samples for best {mode_name} variant ---")
            best_result = sorted(mode_results, key=lambda r: r["metrics"]["composite"], reverse=True)[0]
            for d in best_result["details"]:
                if d.get("error"):
                    continue
                print(f"\n  [{d['index']}]")
                print(f"  Source: {d['source'][:100]}...")
                print(f"  Output: {d['output'][:100]}...")
                print(f"  Ref[0]: {d['references'][0][:100]}...")
                print(f"  GLEU: {d['gleu']:.4f}  Meaning: {d['meaning_preserved']:.1%}")

    # Save
    if args.output:
        output_data = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "modes": {},
        }
        for mode_name, results in all_mode_results.items():
            output_data["modes"][mode_name] = [
                {"metrics": r["metrics"], "details": r["details"]}
                for r in results
            ]
        with open(args.output, "w") as f:
            json.dump(output_data, f, indent=2)
        print(f"\nResults saved to: {args.output}")

    # Final summary
    print(f"\n{'='*70}")
    print("  WINNERS SUMMARY")
    print(f"{'='*70}")
    for mode_name, results in all_mode_results.items():
        best = sorted(results, key=lambda r: r["metrics"]["composite"], reverse=True)[0]
        m = best["metrics"]
        print(f"  {mode_name.upper():15s}  {m['variant']:30s}  composite={m['composite']:.4f}  GLEU={m['avg_gleu']:.4f}  meaning={m['avg_meaning']:.1%}")

    print("\nDone!")


if __name__ == "__main__":
    main()
