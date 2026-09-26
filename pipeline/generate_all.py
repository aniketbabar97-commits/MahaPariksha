"""Bulk-generate the question bank: Gemini drafts, Groq blind-solves as an independent check.

Only items where Groq's blind solve (given just the question+options, no key) agrees with
Gemini's drafted answer are kept and appended to content/bank/<subject>.json. Everything else
is parked to content/parked/<subject>.json for human review, never shipped.

Usage: python pipeline/generate_all.py [SUBJECT...]
Env: GEMINI_API_KEY, GROQ_API_KEY (required)
     GEMINI_MODELS (comma-separated, rotated on daily quota exhaustion), GROQ_MODEL
     TARGET_PER_SUBJECT (default 100), BATCH_SIZE (default 10), MAX_BATCHES (default 12)
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
BANK = CONTENT / "bank"
PARKED = CONTENT / "parked"

GEMINI_KEY = os.environ["GEMINI_API_KEY"]
GROQ_KEY = os.environ["GROQ_API_KEY"]
GEMINI_MODELS = os.environ.get(
    "GEMINI_MODELS", "gemini-2.5-flash,gemini-2.5-flash-lite,gemini-flash-lite-latest,gemma-4-26b-a4b-it"
).split(",")
GROQ_MODEL = os.environ.get("GROQ_MODEL", "openai/gpt-oss-120b")
TARGET = int(os.environ.get("TARGET_PER_SUBJECT", "100"))
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", "10"))
MAX_BATCHES = int(os.environ.get("MAX_BATCHES", "12"))
GEMINI_PACING_SECONDS = float(os.environ.get("GEMINI_PACING_SECONDS", "5"))

SKIP_SUBJECTS = {"current_affairs"}  # handled by the daily pipeline instead
DEVANAGARI = re.compile(r"[ऀ-ॿ]")


class QuotaExhausted(Exception):
    pass


def _post_json(url, payload, headers, timeout=90, retries=4):
    body = json.dumps(payload).encode("utf-8")
    headers = {**headers, "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) BharariGenBot/1.0"}
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 429:
                detail = e.read().decode("utf-8", "replace")
                if "PerDay" in detail or "generate_content_free_tier_requests" in detail:
                    raise QuotaExhausted(detail[:200]) from None
                if attempt == retries - 1:
                    raise
                wait = 15 * (attempt + 1)
                print(f"  rate limited; retrying in {wait}s", file=sys.stderr)
                time.sleep(wait)
                continue
            if attempt == retries - 1:
                raise
            wait = 2 ** attempt * 3
            print(f"  request failed ({e}); retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)
        except (urllib.error.URLError, TimeoutError) as e:
            if attempt == retries - 1:
                raise
            wait = 2 ** attempt * 3
            print(f"  request failed ({e}); retrying in {wait}s", file=sys.stderr)
            time.sleep(wait)


def _extract_json_array(text):
    start = text.find("[")
    if start == -1:
        raise ValueError("no JSON array in response")
    try:
        end = text.rfind("]")
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        pass
    # response was truncated or has one malformed object; parse top-level {...} objects one by one
    items, depth, obj_start, in_str, esc = [], 0, None, False, False
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
        elif c == "{":
            if depth == 0:
                obj_start = i
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0 and obj_start is not None:
                try:
                    items.append(json.loads(text[obj_start:i + 1]))
                except json.JSONDecodeError:
                    pass
                obj_start = None
    if not items:
        raise ValueError("could not recover any JSON objects from response")
    return items


_model_idx = [0]


def gemini_draft(subject, topics, n, avoid):
    for attempt in range(len(GEMINI_MODELS)):
        model = GEMINI_MODELS[_model_idx[0] % len(GEMINI_MODELS)]
        try:
            return _gemini_draft_with_model(model, subject, topics, n, avoid)
        except QuotaExhausted:
            print(f"  {model}: daily quota exhausted, rotating model", file=sys.stderr)
            _model_idx[0] += 1
    raise QuotaExhausted("all Gemini models exhausted for today")


def _gemini_draft_with_model(model, subject, topics, n, avoid):
    avoid_txt = ("\nDo not repeat these already-used question texts (English):\n- "
                 + "\n- ".join(avoid[:60])) if avoid else ""
    prompt = f"""You write multiple-choice questions for Marathi-medium aspirants preparing for
Maharashtra government exams (Police Bharti, Talathi, MPSC Group C/Rajyaseva) and SSC/Railway.

Subject: {subject}
Valid topic ids for this subject (use ONLY these, spread across them): {", ".join(topics)}

Write exactly {n} distinct, exam-relevant, factually correct MCQs for this subject.{avoid_txt}

Rules:
- Each item has a "t" field set to one of the valid topic ids above.
- "d" (difficulty) is 1 (easy), 2 (medium) or 3 (hard); mix them.
- Exactly one correct option; vary which position (0-3) is correct; distractors must be plausible
  but clearly wrong on reflection.
- q_mr/o_mr/e_mr must be natural, grammatically correct Marathi (Devanagari script) unless the
  subject is "english". q_en/o_en/e_en are the English equivalents (same meaning, same option order).
- o_mr and o_en: exactly 4 options each, all non-empty, all distinct.
- a: 0-based index (0-3) of the correct option, matching both o_mr and o_en.
- e_mr/e_en: a 1-3 sentence explanation of why the answer is correct.
- Only state facts you are confident about. Do not invent statistics, dates, or names.

Return ONLY a JSON array (no markdown fences, no commentary) of {n} objects, each with exactly
these keys: t, d, q_mr, q_en, o_mr, o_en, a, e_mr, e_en."""

    url = (f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
           f"?key={GEMINI_KEY}")
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.9, "maxOutputTokens": 16384},
    }
    data = _post_json(url, payload, {"Content-Type": "application/json"})
    if "candidates" not in data or not data["candidates"]:
        raise ValueError(f"gemini: no candidates ({data.get('promptFeedback', data)})")
    parts = data["candidates"][0].get("content", {}).get("parts", [])
    text = "".join(p.get("text", "") for p in parts)
    return _extract_json_array(text)


def groq_blind_solve(q_en, o_en):
    opts = "\n".join(f"{i}. {o}" for i, o in enumerate(o_en))
    prompt = (f"Answer this multiple-choice question. Reply with ONLY a JSON object "
              f'{{"answer_index": 0-3, "confident": true/false}}. Set confident=false if you are '
              f"not sure or the question is ambiguous.\n\nQ: {q_en}\n{opts}")
    url = "https://api.groq.com/openai/v1/chat/completions"
    payload = {
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        "max_tokens": 800,
        "reasoning_effort": "low",
    }
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {GROQ_KEY}"}
    data = _post_json(url, payload, headers)
    text = data["choices"][0]["message"]["content"] or ""
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        return -1, False
    obj = json.loads(text[start:end + 1])
    return int(obj.get("answer_index", -1)), bool(obj.get("confident", False))


def shape_ok(item, topics):
    try:
        if item.get("t") not in topics:
            return False
        if item.get("d") not in (1, 2, 3):
            return False
        for lang in ("mr", "en"):
            opts = item.get(f"o_{lang}")
            if not (isinstance(opts, list) and len(opts) == 4
                    and all(isinstance(o, str) and o.strip() for o in opts)
                    and len({o.strip() for o in opts}) == 4):
                return False
            if not (isinstance(item.get(f"q_{lang}"), str) and item[f"q_{lang}"].strip()):
                return False
            if not (isinstance(item.get(f"e_{lang}"), str) and item[f"e_{lang}"].strip()):
                return False
        if not isinstance(item.get("a"), int) or not 0 <= item["a"] <= 3:
            return False
        return True
    except (TypeError, KeyError):
        return False


def load_bank(file_name):
    path = BANK / f"{file_name}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else []


def process_subject(subject, topics, file_name=None, s=None, target=None):
    """Top up content/bank/<file_name>.json (default: <subject>.json) with items tagged s=<s>
    (default: subject), drawing only from the given topics. Lets one file (e.g. gs_adv, which
    spans several subjects) be filled by several calls against the same file_name."""
    file_name = file_name or subject
    s = s or subject
    target = TARGET if target is None else target
    existing = load_bank(file_name)
    same_s = [q for q in existing if q["s"] == s]
    deficit = target - len(same_s)
    if deficit <= 0:
        print(f"{file_name}/{s}: already has {len(same_s)} >= {target}, skipping")
        return 0, 0
    seen_q = {q["q_en"].strip().lower() for q in existing}
    next_n = max([int(q["id"].split("-")[-1]) for q in existing] or [0]) + 1
    kept, parked = [], []
    batches = 0
    while deficit > 0 and batches < MAX_BATCHES:
        batches += 1
        n = min(BATCH_SIZE, deficit + 3)  # ask for a few extra to absorb rejects
        try:
            drafts = gemini_draft(s, sorted(topics), n, list(seen_q))
        except QuotaExhausted:
            print(f"  {file_name}/{s}: all Gemini models exhausted for today; stopping this run",
                  file=sys.stderr)
            _save_bank(file_name, existing, kept, parked)
            raise
        except Exception as e:
            print(f"  {file_name}/{s}: gemini batch failed: {e}", file=sys.stderr)
            time.sleep(20)
            continue
        time.sleep(GEMINI_PACING_SECONDS)
        for d in drafts:
            if not shape_ok(d, topics):
                parked.append({"reason": "bad_shape", "item": d})
                continue
            q_en_key = d["q_en"].strip().lower()
            if q_en_key in seen_q:
                continue
            if s != "english" and not DEVANAGARI.search(d["q_mr"]):
                parked.append({"reason": "no_devanagari", "item": d})
                continue
            try:
                idx, confident = groq_blind_solve(d["q_en"], d["o_en"])
            except Exception as e:
                parked.append({"reason": f"groq_error: {e}", "item": d})
                continue
            if not confident or idx != d["a"]:
                parked.append({"reason": f"mismatch (gemini={d['a']}, groq={idx}, confident={confident})",
                                "item": d})
                continue
            seen_q.add(q_en_key)
            kept.append({
                "id": f"{file_name}-{next_n:03d}", "s": s, "t": d["t"], "d": d["d"],
                "q_mr": d["q_mr"], "q_en": d["q_en"], "o_mr": d["o_mr"], "o_en": d["o_en"],
                "a": d["a"], "e_mr": d["e_mr"], "e_en": d["e_en"],
            })
            next_n += 1
            deficit -= 1
            if deficit <= 0:
                break
    _save_bank(file_name, existing, kept, parked)
    print(f"{file_name}/{s}: kept {len(kept)}, parked {len(parked)} "
          f"(now {len(same_s) + len(kept)}/{target})")
    return len(kept), len(parked)


def _save_bank(file_name, existing, kept, parked):
    if kept:
        BANK.mkdir(parents=True, exist_ok=True)
        (BANK / f"{file_name}.json").write_text(
            json.dumps(existing + kept, ensure_ascii=False, indent=1), encoding="utf-8")
    if parked:
        PARKED.mkdir(parents=True, exist_ok=True)
        ppath = PARKED / f"{file_name}.json"
        prior = json.loads(ppath.read_text(encoding="utf-8")) if ppath.exists() else []
        ppath.write_text(json.dumps(prior + parked, ensure_ascii=False, indent=1), encoding="utf-8")


# Files that hold extra depth/passage-based topics for a subject beyond its main taxonomy split.
# Each entry maps a bank file to [(s, [topic ids], per-part target), ...]; s and its topics must
# be valid per content/taxonomy.json. These top up alongside the main per-subject pass.
SPECIAL_FILES = {
    "english_rc": [("english", ["comprehension", "cloze", "para_jumble"], 60)],
    "marathi_utara": [("marathi", ["utara"], 40)],
    "maths_adv": [("maths", ["algebra", "geometry", "trigonometry", "statistics",
                              "data_interpretation"], 60)],
    "reasoning_adv": [("reasoning", ["puzzles", "inequality", "data_sufficiency"], 60)],
    "gs_adv": [
        ("geography", ["mh_forests"], 25),
        ("economy", ["social_dev", "mh_economy"], 25),
        ("polity", ["governance", "bodies"], 25),
        ("science", ["sci_tech"], 25),
    ],
}


def main(argv):
    taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    subjects = {s["id"]: [t["id"] for t in s["topics"]] for s in taxonomy["subjects"]
                if s["id"] not in SKIP_SUBJECTS}
    wanted = argv or sorted(subjects) + sorted(SPECIAL_FILES)
    total_kept = total_parked = 0
    for name in wanted:
        try:
            if name in SPECIAL_FILES:
                for s, topics, part_target in SPECIAL_FILES[name]:
                    k, p = process_subject(s, topics, file_name=name, s=s, target=part_target)
                    total_kept += k
                    total_parked += p
            elif name in subjects:
                k, p = process_subject(name, subjects[name])
                total_kept += k
                total_parked += p
            else:
                print(f"unknown subject/file {name}, skipping", file=sys.stderr)
        except QuotaExhausted:
            print(f"\nAll Gemini models exhausted their daily quota; stopping the run here.")
            print(f"TOTAL: kept {total_kept}, parked {total_parked}")
            return 0
    print(f"\nTOTAL: kept {total_kept}, parked {total_parked}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
