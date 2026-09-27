#!/usr/bin/env python3
"""Translate a batch of RUKHSA questions into target languages via the Gemini API.

Usage:
    GEMINI_API_KEY=... python3 translate_via_gemini.py <ids_file.json> <lang1> [lang2 ...]

<ids_file.json> is a JSON array of question ids to translate (must already
exist, fully authored, in content/questions_en.json and questions_ar.json).
For each target language not already covering these ids, calls Gemini once
per language with the full batch, asks for a JSON array back matching the
source id order, and merges the result into content/questions_<lang>.json.

This exists to offload the mechanical, high-volume translation work to a
cheaper/faster model, reserving Claude's own agent time for authoring,
fact verification, and quality review. It does NOT replace review: run
pipeline/validate.py and spot-check a sample after using this script.
"""
import json
import os
import re
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTENT_DIR = os.path.join(ROOT, "content")

LANG_NAMES = {
    "ar": "Arabic", "ur": "Urdu", "hi": "Hindi", "tl": "Tagalog (Filipino)",
    "ml": "Malayalam", "bn": "Bengali", "ta": "Tamil", "fa": "Persian (Farsi)",
    "fr": "French", "zh": "Simplified Chinese", "ru": "Russian", "en": "English",
}

GEMINI_MODEL = "gemini-2.5-flash"
API_KEY = os.environ.get("GEMINI_API_KEY")


def load(lang):
    path = os.path.join(CONTENT_DIR, f"questions_{lang}.json")
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(lang, data):
    path = os.path.join(CONTENT_DIR, f"questions_{lang}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def call_gemini(prompt, retries=3):
    if not API_KEY:
        raise SystemExit("GEMINI_API_KEY not set in environment")
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{GEMINI_MODEL}:generateContent?key={API_KEY}"
    )
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 8192},
    }).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    last_err = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read())
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(2 * (attempt + 1))
    raise RuntimeError(f"Gemini call failed after {retries} attempts: {last_err}")


def extract_json_array(text):
    text = text.strip()
    text = re.sub(r"^```(json)?", "", text.strip())
    text = re.sub(r"```$", "", text.strip())
    return json.loads(text)


def translate_batch(src_items, target_lang):
    lang_name = LANG_NAMES.get(target_lang, target_lang)
    payload = [
        {"id": q["id"], "q": q["q"], "options": q["options"], "explanation": q["explanation"]}
        for q in src_items
    ]
    prompt = (
        f"You are a professional translator localizing UAE RTA driving-theory-test "
        f"questions into {lang_name} for real learners studying for their driving test. "
        f"Translate the 'q', each string in 'options', and 'explanation' fields into "
        f"natural, accurate {lang_name} — do not translate the 'id' field. "
        f"Keep the same meaning and the same number of options in the same order "
        f"(the correct-answer index is tracked separately by id, so option order must "
        f"be preserved exactly). Return ONLY a JSON array, same shape as input "
        f"(objects with id/q/options/explanation), no markdown fences, no commentary.\n\n"
        f"INPUT:\n{json.dumps(payload, ensure_ascii=False)}"
    )
    raw = call_gemini(prompt)
    result = extract_json_array(raw)
    by_id = {r["id"]: r for r in result}
    missing = [q["id"] for q in src_items if q["id"] not in by_id]
    if missing:
        raise RuntimeError(f"{target_lang}: model omitted ids {missing}")
    return by_id


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    ids_file, langs = sys.argv[1], sys.argv[2:]

    with open(ids_file, encoding="utf-8") as f:
        target_ids = set(json.load(f))

    en = load("en")
    en_by_id = {q["id"]: q for q in en}
    src_items = [en_by_id[i] for i in target_ids if i in en_by_id]
    missing_from_en = target_ids - {q["id"] for q in src_items}
    if missing_from_en:
        raise SystemExit(f"ids missing from questions_en.json: {missing_from_en}")

    print(f"Translating {len(src_items)} questions into {len(langs)} language(s)...")

    for lang in langs:
        existing = load(lang)
        existing_ids = {q["id"] for q in existing}
        todo = [q for q in src_items if q["id"] not in existing_ids]
        if not todo:
            print(f"  {lang}: already has all {len(src_items)} ids, skipping")
            continue
        print(f"  {lang}: translating {len(todo)} new questions via Gemini...")
        translated = translate_batch(todo, lang)
        for q in todo:
            t = translated[q["id"]]
            existing.append({
                "id": q["id"], "q": t["q"], "options": t["options"],
                "explanation": t["explanation"],
            })
        existing.sort(key=lambda x: x["id"])
        save(lang, existing)
        print(f"  {lang}: wrote {len(existing)} total questions")

    print("Done. Run pipeline/validate.py and spot-check a sample before trusting this batch.")


if __name__ == "__main__":
    main()
