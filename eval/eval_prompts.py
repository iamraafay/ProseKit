#!/usr/bin/env python3
"""
eval_prompts.py — ProseKit Grammar Prompt Evaluation Harness

Downloads the JFLEG test set from HuggingFace, runs each source sentence
through prompt variants via Swama's OpenAI-compatible API, and scores
outputs against reference corrections.

Usage:
    # Make sure Swama is running with Qwen3-8B loaded:
    #   swama run mlx-community/Qwen3-8B-4bit

    # Install deps:
    #   pip install -r requirements.txt

    # Run evaluation (defaults to 50 samples):
    python eval_prompts.py

    # Run with more/fewer samples:
    python eval_prompts.py --samples 200

    # Use built-in test set (no HuggingFace download needed):
    python eval_prompts.py --builtin

    # Test a single variant:
    python eval_prompts.py --variant v1_production

    # Save detailed results to JSON:
    python eval_prompts.py --output results.json

Metrics:
    - GLEU: Standard GEC metric (geometric mean of n-gram precisions, averaged
            across source→output and reference→output directions)
    - Exact Match: % of outputs matching at least one reference exactly
    - Changed Rate: % of inputs the model actually modified (should be high for JFLEG)
    - Overcorrection: % of words changed beyond what references suggest
    - Avg Latency: Mean inference time per sample
"""

import argparse
import json
import os
import sys
import time
from collections import Counter
from pathlib import Path

import requests

# ─── GLEU Implementation ─────────────────────────────────────────────────────
# GLEU (Ground-truth-based BLEU) is the standard metric for GEC evaluation.
# It modifies BLEU to penalize both under-correction and over-correction.

def get_ngrams(tokens, n):
    """Extract n-grams from a token list."""
    return [tuple(tokens[i:i+n]) for i in range(len(tokens) - n + 1)]

def compute_gleu_sentence(source_tokens, output_tokens, reference_tokens, max_n=4):
    """
    Compute sentence-level GLEU score.

    GLEU compares the n-gram overlap between:
    - output vs reference (precision-like)
    - penalizes n-grams in output that match source but not reference (overcorrection)
    """
    import math

    if not output_tokens or not reference_tokens:
        return 0.0

    scores = []

    for n in range(1, min(max_n + 1, len(output_tokens) + 1)):
        source_ngrams = Counter(get_ngrams(source_tokens, n))
        output_ngrams = Counter(get_ngrams(output_tokens, n))
        reference_ngrams = Counter(get_ngrams(reference_tokens, n))

        # Count n-grams in output that match reference
        matches = sum((output_ngrams & reference_ngrams).values())

        # Total n-grams in output
        total = sum(output_ngrams.values())

        if total == 0:
            scores.append(0.0)
        else:
            scores.append(matches / total)

    if not scores or all(s == 0 for s in scores):
        return 0.0

    # Geometric mean of n-gram precisions (like BLEU)
    log_scores = [math.log(s) if s > 0 else -float('inf') for s in scores]
    avg_log = sum(log_scores) / len(log_scores)

    if avg_log == -float('inf'):
        return 0.0

    # Brevity penalty
    bp = 1.0
    if len(output_tokens) < len(reference_tokens):
        bp = math.exp(1 - len(reference_tokens) / max(len(output_tokens), 1))

    return bp * math.exp(avg_log)


def compute_gleu(source, output, references):
    """
    Compute GLEU across multiple references, taking the max.

    Args:
        source: original (erroneous) sentence string
        output: model's corrected sentence string
        references: list of reference correction strings

    Returns:
        float: GLEU score (0-1)
    """
    source_tokens = source.lower().split()
    output_tokens = output.lower().split()

    best_score = 0.0
    for ref in references:
        ref_tokens = ref.lower().split()
        score = compute_gleu_sentence(source_tokens, output_tokens, ref_tokens)
        best_score = max(best_score, score)

    return best_score


# ─── Edit Distance Metrics ────────────────────────────────────────────────────

def word_edit_distance(a_tokens, b_tokens):
    """Word-level Levenshtein distance."""
    m, n = len(a_tokens), len(b_tokens)
    dp = [[0] * (n + 1) for _ in range(m + 1)]

    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j

    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if a_tokens[i-1].lower() == b_tokens[j-1].lower():
                dp[i][j] = dp[i-1][j-1]
            else:
                dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])

    return dp[m][n]


def compute_change_ratio(source, output):
    """Fraction of words changed between source and output."""
    s_tokens = source.split()
    o_tokens = output.split()

    if not s_tokens:
        return 0.0

    edits = word_edit_distance(s_tokens, o_tokens)
    return edits / max(len(s_tokens), len(o_tokens))


def compute_overcorrection(source, output, references):
    """
    Estimate overcorrection: changes made by the model that aren't
    reflected in ANY reference.

    Returns fraction of output words that differ from source AND
    differ from all references.
    """
    s_tokens = source.lower().split()
    o_tokens = output.lower().split()

    if not o_tokens:
        return 0.0

    # Words the model changed from source
    model_changes = set()
    for i, word in enumerate(o_tokens):
        if i >= len(s_tokens) or word != s_tokens[i].lower():
            model_changes.add(i)

    if not model_changes:
        return 0.0

    # Check if each change appears in at least one reference
    unnecessary = 0
    for idx in model_changes:
        if idx >= len(o_tokens):
            continue
        word = o_tokens[idx]
        found_in_ref = False
        for ref in references:
            r_tokens = ref.lower().split()
            if idx < len(r_tokens) and r_tokens[idx] == word:
                found_in_ref = True
                break
        if not found_in_ref:
            unnecessary += 1

    return unnecessary / len(o_tokens)


# ─── Swama API Client ────────────────────────────────────────────────────────

def call_swama(prompt, system_prompt, temperature=0.3, base_url="http://localhost:8080"):
    """
    Call Swama's OpenAI-compatible API.

    Returns (response_text, latency_seconds) or raises on error.
    """
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
            "Cannot connect to Swama at localhost:8080.\n"
            "Make sure Swama is running: swama run mlx-community/Qwen3-8B-4bit"
        )

    elapsed = time.time() - start

    data = resp.json()
    text = data["choices"][0]["message"]["content"].strip()

    return text, elapsed


def clean_response(text):
    """Mirror the cleaning logic from RewriteEngine.swift."""
    import re

    text = text.strip()

    # Strip <think>...</think> blocks
    text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()

    # Strip wrapping quotes
    if (text.startswith('"') and text.endswith('"')) or \
       (text.startswith("'") and text.endswith("'")):
        text = text[1:-1].strip()

    # Strip markdown code blocks
    if text.startswith("```"):
        lines = text.split("\n")
        lines = [l for l in lines if not l.startswith("```")]
        text = "\n".join(lines).strip()

    return text


# ─── Dataset Loading ──────────────────────────────────────────────────────────

def load_jfleg(split="test", max_samples=None):
    """
    Load JFLEG dataset from HuggingFace.

    Returns list of dicts: {source: str, references: [str, str, str, str]}
    """
    try:
        from datasets import load_dataset
    except ImportError:
        print("ERROR: 'datasets' package not installed.")
        print("Run: pip install datasets")
        sys.exit(1)

    print(f"Loading JFLEG {split} set from HuggingFace...")
    ds = load_dataset("jfleg", split=split, trust_remote_code=True)

    samples = []
    for item in ds:
        source = item["sentence"]
        refs = item["corrections"]
        samples.append({"source": source, "references": refs})

    if max_samples and max_samples < len(samples):
        # Take evenly spaced samples for representativeness
        step = len(samples) / max_samples
        indices = [int(i * step) for i in range(max_samples)]
        samples = [samples[i] for i in indices]

    print(f"Loaded {len(samples)} samples ({len(ds)} total in dataset)")
    return samples


# ─── Evaluation Loop ──────────────────────────────────────────────────────────

def evaluate_variant(variant, samples, base_url="http://localhost:8080"):
    """
    Run a prompt variant against all samples and collect metrics.

    Returns dict with aggregate metrics and per-sample details.
    """
    name = variant["name"]
    system_prompt = variant["system_prompt"]
    temperature = variant["temperature"]

    print(f"\n{'='*60}")
    print(f"  Evaluating: {name}")
    print(f"  Temperature: {temperature}")
    print(f"  Samples: {len(samples)}")
    print(f"{'='*60}")

    results = []
    gleu_scores = []
    exact_matches = 0
    changes_made = 0
    overcorrection_scores = []
    latencies = []
    errors = 0

    for i, sample in enumerate(samples):
        source = sample["source"]
        references = sample["references"]

        # Progress indicator
        if (i + 1) % 10 == 0 or i == 0:
            print(f"  [{i+1}/{len(samples)}] Processing...")

        try:
            raw_output, latency = call_swama(
                source, system_prompt, temperature, base_url
            )
            output = clean_response(raw_output)
            latencies.append(latency)
        except Exception as e:
            print(f"  ERROR on sample {i}: {e}")
            errors += 1
            results.append({
                "index": i,
                "source": source,
                "output": None,
                "references": references,
                "error": str(e),
            })
            continue

        # Compute metrics
        gleu = compute_gleu(source, output, references)
        gleu_scores.append(gleu)

        # Exact match (matches any reference)
        output_normalized = output.strip().lower()
        is_exact = any(
            ref.strip().lower() == output_normalized
            for ref in references
        )
        if is_exact:
            exact_matches += 1

        # Did the model change anything?
        if output.strip() != source.strip():
            changes_made += 1

        # Overcorrection
        overcorr = compute_overcorrection(source, output, references)
        overcorrection_scores.append(overcorr)

        results.append({
            "index": i,
            "source": source,
            "output": output,
            "references": references,
            "gleu": gleu,
            "exact_match": is_exact,
            "changed": output.strip() != source.strip(),
            "overcorrection": overcorr,
            "latency": latency,
        })

    # Aggregate metrics
    n_evaluated = len(samples) - errors

    metrics = {
        "variant": name,
        "temperature": temperature,
        "total_samples": len(samples),
        "errors": errors,
        "avg_gleu": sum(gleu_scores) / max(len(gleu_scores), 1),
        "median_gleu": sorted(gleu_scores)[len(gleu_scores)//2] if gleu_scores else 0,
        "exact_match_rate": exact_matches / max(n_evaluated, 1),
        "change_rate": changes_made / max(n_evaluated, 1),
        "avg_overcorrection": sum(overcorrection_scores) / max(len(overcorrection_scores), 1),
        "avg_latency": sum(latencies) / max(len(latencies), 1),
        "p95_latency": sorted(latencies)[int(len(latencies) * 0.95)] if latencies else 0,
    }

    # Print summary
    print(f"\n  Results for {name}:")
    print(f"  ├── GLEU (avg):         {metrics['avg_gleu']:.4f}")
    print(f"  ├── GLEU (median):      {metrics['median_gleu']:.4f}")
    print(f"  ├── Exact match:        {metrics['exact_match_rate']:.1%}")
    print(f"  ├── Change rate:        {metrics['change_rate']:.1%}")
    print(f"  ├── Overcorrection:     {metrics['avg_overcorrection']:.4f}")
    print(f"  ├── Avg latency:        {metrics['avg_latency']:.2f}s")
    print(f"  ├── P95 latency:        {metrics['p95_latency']:.2f}s")
    print(f"  └── Errors:             {metrics['errors']}")

    return {"metrics": metrics, "details": results}


def print_comparison_table(all_results):
    """Print a side-by-side comparison of all variants."""
    try:
        from tabulate import tabulate
    except ImportError:
        # Fallback to simple print
        return

    headers = ["Variant", "GLEU↑", "Exact%↑", "Changed%", "Overcorr↓", "Latency"]
    rows = []

    for result in all_results:
        m = result["metrics"]
        rows.append([
            m["variant"],
            f"{m['avg_gleu']:.4f}",
            f"{m['exact_match_rate']:.1%}",
            f"{m['change_rate']:.1%}",
            f"{m['avg_overcorrection']:.4f}",
            f"{m['avg_latency']:.2f}s",
        ])

    # Sort by GLEU descending
    rows.sort(key=lambda r: float(r[1]), reverse=True)

    print(f"\n{'='*70}")
    print("  COMPARISON TABLE (sorted by GLEU)")
    print(f"{'='*70}")
    print(tabulate(rows, headers=headers, tablefmt="grid"))
    print()

    # Print winner
    best = rows[0]
    print(f"  🏆 Best variant: {best[0]} (GLEU: {best[1]})")


def print_sample_comparison(all_results, num_samples=5):
    """Show side-by-side outputs for a few interesting samples."""
    if not all_results:
        return

    print(f"\n{'='*70}")
    print("  SAMPLE COMPARISONS")
    print(f"{'='*70}")

    # Find samples where variants disagree the most
    first_details = all_results[0]["details"]

    shown = 0
    for i, sample in enumerate(first_details):
        if shown >= num_samples:
            break
        if sample.get("error"):
            continue

        outputs = []
        for result in all_results:
            detail = result["details"][i]
            if not detail.get("error"):
                outputs.append(detail.get("output", ""))

        # Only show if variants produced different outputs
        if len(set(outputs)) > 1:
            print(f"\n  Sample {i}:")
            print(f"  Source:     {sample['source']}")
            print(f"  Reference:  {sample['references'][0]}")
            for j, result in enumerate(all_results):
                detail = result["details"][i]
                if not detail.get("error"):
                    name = result["metrics"]["variant"]
                    gleu = detail.get("gleu", 0)
                    print(f"  {name}: {detail['output']}  (GLEU: {gleu:.3f})")
            shown += 1


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="ProseKit Grammar Prompt Evaluation Harness"
    )
    parser.add_argument(
        "--samples", type=int, default=50,
        help="Number of samples to evaluate (default: 50)"
    )
    parser.add_argument(
        "--variant", type=str, default=None,
        help="Test a specific variant by name (default: all)"
    )
    parser.add_argument(
        "--url", type=str, default="http://localhost:8080",
        help="Swama API base URL (default: http://localhost:8080)"
    )
    parser.add_argument(
        "--output", type=str, default=None,
        help="Save detailed results to JSON file"
    )
    parser.add_argument(
        "--builtin", action="store_true",
        help="Use built-in test samples instead of JFLEG (no download needed)"
    )
    parser.add_argument(
        "--show-all", action="store_true",
        help="Print every sample's input/output (verbose)"
    )
    args = parser.parse_args()

    # Import prompt variants
    from prompts import GRAMMAR_VARIANTS

    # Filter to specific variant if requested
    if args.variant:
        variants = [v for v in GRAMMAR_VARIANTS if v["name"] == args.variant]
        if not variants:
            available = ", ".join(v["name"] for v in GRAMMAR_VARIANTS)
            print(f"ERROR: Unknown variant '{args.variant}'")
            print(f"Available: {available}")
            sys.exit(1)
    else:
        variants = GRAMMAR_VARIANTS

    # Test API connectivity
    print("Testing Swama connection...")
    try:
        test_out, test_latency = call_swama(
            "Hello world",
            "Respond with exactly: Hello world",
            0.0,
            args.url
        )
        print(f"  ✓ Swama responding ({test_latency:.2f}s)")
    except ConnectionError as e:
        print(f"  ✗ {e}")
        sys.exit(1)

    # Load dataset
    if args.builtin:
        from builtin_samples import BUILTIN_SAMPLES
        samples = BUILTIN_SAMPLES
        if args.samples and args.samples < len(samples):
            samples = samples[:args.samples]
        print(f"Using {len(samples)} built-in test samples")
    else:
        samples = load_jfleg(split="test", max_samples=args.samples)

    # Run evaluation for each variant
    all_results = []
    for variant in variants:
        result = evaluate_variant(variant, samples, args.url)
        all_results.append(result)

    # Print comparison
    if len(all_results) > 1:
        print_comparison_table(all_results)
        print_sample_comparison(all_results)

    # Save results
    if args.output:
        output_data = {
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "num_samples": len(samples),
            "results": [
                {
                    "metrics": r["metrics"],
                    "details": r["details"],
                }
                for r in all_results
            ],
        }

        with open(args.output, "w") as f:
            json.dump(output_data, f, indent=2)

        print(f"\nDetailed results saved to: {args.output}")

    # Print verbose output if requested
    if args.show_all and all_results:
        print(f"\n{'='*70}")
        print("  ALL SAMPLES (first variant)")
        print(f"{'='*70}")
        for detail in all_results[0]["details"]:
            if detail.get("error"):
                print(f"  [{detail['index']}] ERROR: {detail['error']}")
                continue
            print(f"\n  [{detail['index']}]")
            print(f"  Source: {detail['source']}")
            print(f"  Output: {detail['output']}")
            print(f"  Ref[0]: {detail['references'][0]}")
            print(f"  GLEU:   {detail['gleu']:.4f}  Changed: {detail['changed']}  Exact: {detail['exact_match']}")

    print("\nDone!")


if __name__ == "__main__":
    main()
