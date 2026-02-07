#!/usr/bin/env python3
"""ProseKit LLM Quality Test Suite — Tests four rewrite modes against sample texts via Swama API."""

import json
import urllib.request
import time
import os
import re

API_URL = "http://localhost:28100/v1/chat/completions"
MODEL = "mlx-community/Qwen3-8B-4bit"  # Swama's default qwen3 alias
OUTPUT_FILE = os.path.expanduser("~/Projects/GrammarlyReplacement/iteration-0/llm_test_results_v2.md")

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
8. Do NOT wrap your response in quotes.

/no_think"""

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

# ─── Helpers ───────────────────────────────────────────────

def strip_thinking(text):
    """Remove <think>...</think> blocks from model output."""
    cleaned = re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()
    return cleaned if cleaned else None  # None means thinking consumed entire output


# ─── API Call ───────────────────────────────────────────────

def _single_request(system_prompt, text):
    """Make a single API request and return (raw_content, elapsed)."""
    payload = json.dumps({
        "model": MODEL,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text}
        ],
        "temperature": 0.7,
        "top_p": 0.8,
        "max_tokens": 2048
    }).encode("utf-8")

    req = urllib.request.Request(API_URL, data=payload, headers={"Content-Type": "application/json"})

    start = time.time()
    with urllib.request.urlopen(req, timeout=60) as resp:
        result = json.loads(resp.read().decode())
        elapsed = time.time() - start
        content = result["choices"][0]["message"]["content"].strip()
        return content, round(elapsed, 2)


def rewrite(text, mode_name):
    system_prompt = SYSTEM_TEMPLATE.format(mode_instruction=MODES[mode_name])
    max_retries = 2
    total_elapsed = 0
    had_thinking = False

    for attempt in range(1 + max_retries):
        try:
            raw, elapsed = _single_request(system_prompt, text)
            total_elapsed += elapsed

            # Check for <think> tags and strip them
            if '<think>' in raw:
                had_thinking = True
                cleaned = strip_thinking(raw)
                if cleaned is None:
                    # Thinking consumed entire output — retry
                    if attempt < max_retries:
                        print(f"[retry {attempt+1}]", end=" ", flush=True)
                        continue
                    return "ERROR: thinking consumed entire output after retries", round(total_elapsed, 2)
                return cleaned, round(total_elapsed, 2)
            else:
                return raw, round(elapsed, 2)

        except Exception as e:
            return f"ERROR: {e}", 0

    return "ERROR: max retries exceeded", round(total_elapsed, 2)


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
