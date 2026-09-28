# Content generation pipeline

Scripts for bulk-drafting RailPariksha's question banks and topic notes via
free-tier LLM APIs (Groq and Gemini), plus an independent fact-check pass.
Requires `GROQ_API_KEY` and/or `GEMINI_API_KEY` in the environment.

## Scripts

- `bulk_questions.py` -- tops up `content/bank/<subject>.json` toward a per-topic
  target (300 questions/topic, 15/topic for `current_affairs` since those facts
  age out). Resumable, dedups by normalized question text.
- `notes.py` -- drafts `content/notes/<subject>.json` entries (summary, facts,
  mind-map) for every topic that doesn't have one yet.
- `factcheck.py` -- blind-solves stored questions with a second model and
  reports disagreements for review (does not auto-edit anything).
- `_providers.py` -- shared HTTP glue for both providers, not run directly.

## Free-tier quotas reset per model, not per account

Both Groq and Gemini meter usage **per model id**, independently. When a
script starts hitting persistent `429`s, don't just wait ~24h -- switch
`--model` to a different model on the same provider and you likely get a
completely fresh quota immediately. Confirmed empirically (2026-09-28):

- Groq: `openai/gpt-oss-120b` has its own 200,000 tokens/day budget, separate
  from `qwen/qwen3.8-27b`, `openai/gpt-oss-20b`, `allam-2-7b`. Check
  `curl https://api.groq.com/openai/v1/models -H "Authorization: Bearer $GROQ_API_KEY"`
  for the current list on this account.
- Gemini: `gemini-2.5-flash-lite`'s free tier was capped at a mere 20
  requests/day on this project; `gemini-2.5-flash` and `gemini-flash-lite-latest`
  had separate, untouched quotas.

When a script errors with `429`, the response body names the exact limit type
(tokens/day, requests/day, requests/minute) and a retry delay -- read it
before assuming the whole provider is exhausted; it's usually just that one
model.

## Running two instances concurrently

Both `bulk_questions.py` and `notes.py` do a read-modify-write on the target
JSON file with no locking. Running two instances against the **same subject**
at the same time is a race condition -- last writer wins, silently dropping or
duplicating entries. Always split `--subjects` into disjoint sets when running
a Groq instance and a Gemini instance side by side, e.g.:

```bash
python3 bulk_questions.py --provider groq   --model qwen/qwen3.8-27b --subjects maths,reasoning,gk,current_affairs,railway_gk --max-calls 500 &
python3 bulk_questions.py --provider gemini --model gemini-2.5-flash --subjects science,computer,english --max-calls 500 &
```

## Quality control

`bulk_questions.py`'s own prompt asks the model not to invent unstable facts,
but LLM-drafted content should still be spot-checked. Run `factcheck.py`
periodically against a second (ideally different-provider) model and review
`disagreements.json` by hand -- don't auto-apply its verdict, since a
"disagreement" can just as easily mean the fact-checker is wrong.
