"""Turn staged PYQs (normalize.py output) into bilingual, explained, verified bank items.

Per batch of staged questions:
  1. WRITER model: Hindi translation of question + options, fresh explanations in
     Hindi and English, taxonomy topic, difficulty -- and a verdict on whether the
     item is usable as text (rejects garbled PDF extraction, e.g. lost exponents).
  2. SOLVER model (a different provider): solves each question blind, without the
     official key. An item is kept only if the blind answer matches the official
     key -- so a mis-extracted key, a garbled stem or a contested question is
     dropped rather than shipped with a wrong answer.

Resumable: every decision is appended to state/<source>.jsonl, keyed by sid.
`--merge` then writes content/bank/pyq_<source>.json from the kept items.

  python3 pipeline/pyq/enrich.py --source rrb_je --limit 40
  python3 pipeline/pyq/enrich.py --source rrb_je --merge
"""
import argparse
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE.parent / "content_gen"))
from _providers import ask  # noqa: E402

TAXONOMY = json.loads((ROOT / "content/taxonomy.json").read_text(encoding="utf-8"))
TOPICS = {s["id"]: [t["id"] for t in s["topics"]] for s in TAXONOMY["subjects"]}
DEVANAGARI = re.compile(r"[ऀ-ॿ]")
ID_PREFIX = {"rrb_je": "pyq-je", "ssc": "pyq-ssc", "practice": "rp-ghx"}

WRITE_PROMPT = """You are preparing REAL previous-year exam questions (Indian railway / SSC
government exams) for a bilingual Hindi + English exam-prep app used by Hindi-medium students.
Each item below is an official question with its 4 options and the OFFICIAL answer index (0-3).

For EACH item return an object with:
- "i": the item's index as given
- "ok": false if the item is not usable as plain text: garbled or incomplete text, missing data,
  exponents/fractions/symbols clearly lost in PDF extraction (e.g. "53 × 82" that must have been
  5³ × 8²), refers to a figure/table not present, has no single correct option, or the official
  answer is plainly wrong. Otherwise true.
- "why": if ok is false, a short reason. Otherwise "".
- "q_en": the English question, unchanged except fixing obvious spacing/typo artifacts. Never change
  numbers, names or meaning.
- "o_en": the 4 English options, same order, unchanged except whitespace.
- "q_hi": natural, exam-style Hindi (Devanagari) translation of the question, as RRB/SSC Hindi papers
  write it. Keep numbers, units, symbols, letter/number sequences and code words exactly as is.
- "o_hi": the 4 options in Hindi, same order. Keep numbers, symbols, formulas, letter codes and
  proper names unchanged (transliterate names into Devanagari only if that is how Hindi papers print them).
- "t": the best topic id from this list: {topics}
- "d": difficulty 1 (easy), 2 (medium) or 3 (hard) for an average aspirant
- "e_en": a clear 1-4 sentence English explanation of why the official answer is correct, showing the
  key step or calculation. Write it yourself, concisely.
- "e_hi": the same explanation in natural Hindi (Devanagari).
{english_rule}
Subject: {subject}
Items:
{items}

Return JSON: {{"items": [ ... one object per item ... ]}}"""

ENGLISH_RULE = """
SPECIAL RULE (English-language subject): the question tests English itself, so do NOT translate
the English sentence or the options. "q_hi" = a short Hindi instruction (e.g. "दिए गए वाक्य में
रिक्त स्थान के लिए सबसे उपयुक्त शब्द चुनें।") followed by a newline and the original English text
verbatim. "o_hi" = the 4 English options verbatim. "e_hi" = Hindi explanation (English words quoted as is).
"""

SOLVE_PROMPT = """Solve each multiple-choice question independently. Work carefully; these are from
real government exams (maths, reasoning, science, GK, English). Options are numbered 0-3.

{items}

Return JSON: {{"answers": [{{"i": <item index>, "answer_index": <0-3>, "confident": <true/false>}}, ...]}}"""


def fmt_items(rows, with_key):
    out = []
    for i, r in enumerate(rows):
        opts = "\n".join(f"   {k}. {o}" for k, o in enumerate(r["o"]))
        s = f"[{i}] (topic hint: {r.get('topic_hint') or '-'})\n{r['q']}\n{opts}"
        if with_key:
            s += f"\n   OFFICIAL ANSWER INDEX: {r['a']}"
        out.append(s)
    return "\n\n".join(out)


def load_state(path):
    done = {}
    if path.exists():
        for line in path.open(encoding="utf-8"):
            rec = json.loads(line)
            done[rec["sid"]] = rec
    return done


def good(item, r):
    try:
        if r["subj"] != "english" and not DEVANAGARI.search(item["q_hi"]):
            return "q_hi not Hindi"
        for k in ("q_en", "q_hi", "e_en", "e_hi"):
            if not (isinstance(item[k], str) and item[k].strip()):
                return f"{k} empty"
        for k in ("o_en", "o_hi"):
            o = item[k]
            if not (isinstance(o, list) and len(o) == 4 and all(isinstance(x, str) and x.strip() for x in o)):
                return f"{k} malformed"
            if len({x.strip() for x in o}) != 4:
                return f"{k} duplicate options"
        if [x.strip() for x in item["o_en"]] != [x.strip() for x in r["o"]]:
            # The writer may only touch whitespace; anything else risks moving the key.
            if [re.sub(r"\s+", "", x) for x in item["o_en"]] != [re.sub(r"\s+", "", x) for x in r["o"]]:
                return "o_en changed"
        if item["t"] not in TOPICS[r["subj"]]:
            return f"bad topic {item['t']}"
        if item["d"] not in (1, 2, 3):
            return "bad difficulty"
    except (KeyError, TypeError):
        return "missing fields"
    return None


def process_batch(rows, a):
    subj = rows[0]["subj"]
    prompt = WRITE_PROMPT.format(
        topics=", ".join(TOPICS[subj]), subject=subj,
        english_rule=ENGLISH_RULE if subj == "english" else "", items=fmt_items(rows, True))
    kw = {"api_key_env": a.writer_key} if a.writer_provider == "gemini" else {}
    written = ask(a.writer_provider, a.writer_model, prompt, temperature=0.2, **kw).get("items", [])
    by_i = {w.get("i"): w for w in written if isinstance(w, dict)}
    solve = ask(a.solver_provider, a.solver_model,
                SOLVE_PROMPT.format(items=fmt_items(rows, False)), temperature=0.1).get("answers", [])
    solved = {s.get("i"): s for s in solve if isinstance(s, dict)}
    recs = []
    for i, r in enumerate(rows):
        w, s = by_i.get(i), solved.get(i)
        rec = {"sid": r["sid"]}
        if not w:
            rec.update(status="retry", reason="writer skipped item")
        elif not w.get("ok"):
            rec.update(status="rejected", reason="writer: " + str(w.get("why", ""))[:200])
        elif not s:
            rec.update(status="retry", reason="solver skipped item")
        elif s.get("answer_index") != r["a"]:
            rec.update(status="rejected", reason=f"blind solve picked {s.get('answer_index')}, key {r['a']}")
        elif (err := good(w, r)):
            rec.update(status="retry", reason=err)
        else:
            item = {"s": subj, "t": w["t"], "d": w["d"],
                    "q_hi": w["q_hi"].strip(), "q_en": w["q_en"].strip(),
                    "o_hi": [x.strip() for x in w["o_hi"]], "o_en": [x.strip() for x in r["o"]],
                    "a": r["a"], "e_hi": w["e_hi"].strip(), "e_en": w["e_en"].strip()}
            if r.get("label"):
                item["pyq"] = r["label"]
            rec.update(status="kept", item=item)
        recs.append(rec)
    return recs


def run(a):
    rows = [json.loads(l) for l in (HERE / "staging" / f"{a.source}.jsonl").open(encoding="utf-8")]
    state_path = HERE / "state" / f"{a.source}.jsonl"
    state_path.parent.mkdir(exist_ok=True)
    done = load_state(state_path)
    todo = [r for r in rows if done.get(r["sid"], {}).get("status") in (None, "retry")]
    if a.subjects:
        todo = [r for r in todo if r["subj"] in a.subjects.split(",")]
    todo = todo[: a.limit] if a.limit else todo
    print(f"{a.source}: {len(rows)} staged, {len(todo)} to process", flush=True)
    # Batches never mix subjects (the prompt's topic list is per subject).
    batches, cur = [], []
    for r in sorted(todo, key=lambda r: r["subj"]):
        if cur and (len(cur) == a.batch or cur[0]["subj"] != r["subj"]):
            batches.append(cur)
            cur = []
        cur.append(r)
    if cur:
        batches.append(cur)
    stats = {"kept": 0, "rejected": 0, "retry": 0}
    for bi, batch in enumerate(batches):
        try:
            recs = process_batch(batch, a)
        except Exception as e:
            print(f"  batch {bi} ERROR {e}", file=sys.stderr, flush=True)
            if "429" in str(e):
                print("  rate-limited; stopping (rerun to resume, or switch --*-model)", flush=True)
                break
            time.sleep(5)
            continue
        with state_path.open("a", encoding="utf-8") as f:
            for rec in recs:
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                stats[rec["status"]] += 1
        print(f"  batch {bi + 1}/{len(batches)} {batch[0]['subj']}: {stats}", flush=True)
        time.sleep(a.sleep)


def merge(a):
    rows = [json.loads(l) for l in (HERE / "staging" / f"{a.source}.jsonl").open(encoding="utf-8")]
    done = load_state(HERE / "state" / f"{a.source}.jsonl")
    out = []
    for n, r in enumerate(rows, 1):  # ids follow staging order, so they're stable across reruns
        rec = done.get(r["sid"])
        if rec and rec["status"] == "kept":
            out.append({"id": f"{ID_PREFIX[a.source]}-{n:05d}", **rec["item"]})
    dest = ROOT / "content/bank" / ("practice_github.json" if a.source == "practice" else f"pyq_{a.source}.json")
    dest.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    from collections import Counter
    st = Counter(rec["status"] for rec in done.values())
    print(f"{dest.relative_to(ROOT)}: {len(out)} items  (state: {dict(st)})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--subjects")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--batch", type=int, default=6)
    ap.add_argument("--sleep", type=float, default=2)
    ap.add_argument("--writer-provider", default="gemini")
    ap.add_argument("--writer-model", default="gemini-3.8-flash")
    ap.add_argument("--writer-key", default="GEMINI_API_KEY", help="env var holding the Gemini key")
    ap.add_argument("--solver-provider", default="groq")
    ap.add_argument("--solver-model", default="openai/gpt-oss-120b")
    ap.add_argument("--merge", action="store_true")
    a = ap.parse_args()
    merge(a) if a.merge else run(a)
