#!/usr/bin/env python3
"""
quick_test.py — Manually test prompt variants on custom inputs.

Useful for rapid iteration: type a sentence, see how each variant handles it.

Usage:
    python quick_test.py "I goes to the store yesterday"
    python quick_test.py "Their going too the park with there freinds"
    python quick_test.py --variant v3_few_shot "She dont know what to do"
"""

import argparse
import sys
import time
import requests

def call_swama(prompt, system_prompt, temperature=0.3, base_url="http://localhost:8080"):
    """Call Swama's OpenAI-compatible API."""
    import re

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
        print("ERROR: Cannot connect to Swama at localhost:8080")
        print("Run: swama run mlx-community/Qwen3-8B-4bit")
        sys.exit(1)

    elapsed = time.time() - start
    data = resp.json()
    text = data["choices"][0]["message"]["content"].strip()

    # Clean response
    text = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    if (text.startswith('"') and text.endswith('"')) or \
       (text.startswith("'") and text.endswith("'")):
        text = text[1:-1].strip()
    if text.startswith("```"):
        lines = text.split("\n")
        lines = [l for l in lines if not l.startswith("```")]
        text = "\n".join(lines).strip()

    return text, elapsed


def main():
    parser = argparse.ArgumentParser(description="Quick-test prompt variants")
    parser.add_argument("text", help="Text to correct")
    parser.add_argument("--variant", type=str, default=None, help="Specific variant")
    parser.add_argument("--url", type=str, default="http://localhost:8080")
    args = parser.parse_args()

    from prompts import GRAMMAR_VARIANTS

    variants = GRAMMAR_VARIANTS
    if args.variant:
        variants = [v for v in variants if v["name"] == args.variant]
        if not variants:
            print(f"Unknown variant: {args.variant}")
            sys.exit(1)

    print(f"\nInput: {args.text}\n")

    for variant in variants:
        name = variant["name"]
        try:
            output, latency = call_swama(
                args.text,
                variant["system_prompt"],
                variant["temperature"],
                args.url,
            )
            changed = "CHANGED" if output.strip() != args.text.strip() else "unchanged"
            print(f"  {name:25s} → {output}  ({latency:.2f}s, {changed})")
        except Exception as e:
            print(f"  {name:25s} → ERROR: {e}")

    print()


if __name__ == "__main__":
    main()
