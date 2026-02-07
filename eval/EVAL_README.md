# ProseKit Prompt Evaluation Harness

Evaluate and compare grammar correction prompts against the JFLEG dataset.

## Setup

```bash
cd eval
pip install -r requirements.txt
```

Make sure Swama is running with Qwen3-8B:
```bash
swama run mlx-community/Qwen3-8B-4bit
```

## Quick Test (single sentences)

```bash
# Test all variants on a sentence
python quick_test.py "I goes to the store yesterday"

# Test one variant
python quick_test.py --variant v1_production "Their going too the park"
```

## Full Evaluation

```bash
# Default: 50 samples, all variants
python eval_prompts.py

# More samples (slower, more accurate)
python eval_prompts.py --samples 200

# Single variant
python eval_prompts.py --variant v3_few_shot --samples 100

# Save results
python eval_prompts.py --samples 100 --output results.json

# Verbose (print every sample)
python eval_prompts.py --samples 20 --show-all
```

## Adding New Prompt Variants

Edit `prompts.py` and add a new dict to `GRAMMAR_VARIANTS`:

```python
GRAMMAR_V6 = {
    "name": "v6_my_new_prompt",
    "system_prompt": """Your new prompt here...

/no_think""",
    "temperature": 0.3,
}

GRAMMAR_VARIANTS.append(GRAMMAR_V6)
```

Then re-run evaluation to compare.

## Metrics

| Metric | What it measures | Good = |
|--------|-----------------|--------|
| GLEU | N-gram overlap with references | Higher |
| Exact Match | Output matches a reference exactly | Higher |
| Change Rate | % of inputs modified | Higher for JFLEG |
| Overcorrection | Changes not justified by references | Lower |
| Latency | Inference time per sample | Lower |

## File Structure

- `prompts.py` — All prompt variants (edit this to iterate)
- `eval_prompts.py` — Main evaluation harness
- `quick_test.py` — Test variants on custom inputs
- `requirements.txt` — Python dependencies
