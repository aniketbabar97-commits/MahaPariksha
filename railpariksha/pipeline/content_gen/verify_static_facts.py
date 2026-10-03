#!/usr/bin/env python3
"""Fact-check pass over content/gk_booster.json and content/cheat_sheets/*.json --
plain reference facts (not MCQs), so verify_questions.py's prompt/schema doesn't fit.
Same spirit: flags candidates to pipeline/logs/verify_flags/<name>.jsonl for a human
(or Claude) to personally check before anything is changed -- never auto-applied.

Usage:
    python3 verify_static_facts.py --provider groq --model openai/gpt-oss-120b --batch-size 15
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from _providers import ask  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FLAGS_DIR = os.path.join(ROOT, "pipeline", "logs", "verify_flags")

PROMPT = """You are fact-checking short reference facts for an Indian Railways (RRB/RPF) exam-prep
app's static GK booster / cheat-sheet content. Today's date is October 2026.

For each numbered item below, check:
1. Is the stated fact actually true?
2. If it names a "current" office-holder, record, or figure (e.g. who holds a post, a scheme's current
   amount, a latest edition/year), is it still accurate as of October 2026, not an outdated one?
3. Any fabricated/nonexistent entity, date, or statistic?

Items:
{items}

Output ONLY a JSON object, no markdown fences:
{{"results": [{{"id": "<id>", "ok": true}}, {{"id": "<id>", "ok": false, "problem": "one sentence"}}]}}
One result per item, using the exact id given. Only flag a real, specific problem you're confident
about."""


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def append_flag(name, entry):
    os.makedirs(FLAGS_DIR, exist_ok=True)
    with open(f"{FLAGS_DIR}/{name}.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def load_gk_booster():
    d = json.load(open(f"{ROOT}/content/gk_booster.json", encoding="utf-8"))
    items = []
    for cat in d["categories"]:
        for i, it in enumerate(cat["items"]):
            items.append({
                "id": f"gkb-{cat['id']}-{i:03d}",
                "text": f"{it['title_en']} -- {it['detail_en']}",
            })
    return items


def load_cheat_sheets():
    items = []
    for fn in sorted(os.listdir(f"{ROOT}/content/cheat_sheets")):
        subj = os.path.splitext(fn)[0]
        d = json.load(open(f"{ROOT}/content/cheat_sheets/{fn}", encoding="utf-8"))
        for cat in d:
            for i, bullet in enumerate(cat["items_en"]):
                items.append({
                    "id": f"cs-{subj}-{cat['id']}-{i:03d}",
                    "text": f"[{cat['cat_en']}] {bullet}",
                })
    return items


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--batch-size", type=int, default=15)
    p.add_argument("--gemini-key-env", default="GEMINI_API_KEY")
    args = p.parse_args()

    all_items = load_gk_booster() + load_cheat_sheets()
    print(f"loaded {len(all_items)} static reference items to check", flush=True)

    flagged = 0
    for batch in chunks(all_items, args.batch_size):
        by_id = {it["id"]: it for it in batch}
        items_text = "\n".join(f'{i+1}. id="{it["id"]}": {it["text"]}' for i, it in enumerate(batch))
        prompt = PROMPT.format(items=items_text)
        try:
            kw = {"api_key_env": args.gemini_key_env} if args.provider == "gemini" else {}
            result = ask(args.provider, args.model, prompt, temperature=0.1, **kw)
        except Exception as e:
            print(f"ERROR on batch starting {batch[0]['id']}: {e}", file=sys.stderr, flush=True)
            time.sleep(3)
            continue
        results = result if isinstance(result, list) else result.get("results", [])
        for r in results:
            qid = r.get("id")
            if qid not in by_id:
                continue
            if not r.get("ok", True):
                flagged += 1
                append_flag("static_facts", {"id": qid, "text": by_id[qid]["text"],
                                              "problem": r.get("problem", "")})
                print(f"FLAGGED {qid}: {r.get('problem', '')}", flush=True)
        time.sleep(1.5 if args.provider == "groq" else 2.0)
    print(f"done, {flagged} flagged out of {len(all_items)}")


if __name__ == "__main__":
    main()
