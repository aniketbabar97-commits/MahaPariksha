#!/usr/bin/env python3
"""
Builds rukhsa/app/assets/content/bundle.json from:
  - rukhsa/content/taxonomy.json
  - rukhsa/content/bank/*.json  (authored source, see author_bank.py)

For every question, this script:
  1. Keeps the authored text as-is (translationStatus: "done") for every
     language that is present inline on the question object in the bank file
     (currently "en", "ar", "zh" and "ru").
  2. Fills any remaining languages (ur, hi, tl, ml, bn, ta, fa, fr) with the
     English text plus translationStatus: "pending", so the app can clearly
     mark/filter untranslated content instead of silently showing fake
     translations. If a per-language override file
     rukhsa/content/questions_<lang>.json (a flat list of
     {id, q, options, explanation}) exists for one of these languages, its
     text is used instead, with translationStatus: "done".

Run: python3 rukhsa/pipeline/build_bundle.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
CONTENT_DIR = os.path.join(ROOT, "content")
BANK_DIR = os.path.join(CONTENT_DIR, "bank")
OUT_PATH = os.path.join(ROOT, "app", "assets", "content", "bundle.json")

AUTHORED_LANGS = ["en", "ar", "zh", "ru"]
FALLBACK_LANGS = ["ur", "hi", "tl", "ml", "bn", "ta", "fa", "fr"]
ALL_LANGS = AUTHORED_LANGS + FALLBACK_LANGS


def load_overrides():
    """Loads optional rukhsa/content/questions_<lang>.json override files for
    the fallback languages, keyed by question id."""
    overrides = {}
    for lang in FALLBACK_LANGS:
        path = os.path.join(CONTENT_DIR, f"questions_{lang}.json")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            items = json.load(f)
        overrides[lang] = {item["id"]: item for item in items if "id" in item}
    return overrides


def build_localized_field(en_value, authored, key):
    field = {"en": {"text": en_value, "translationStatus": "done"}}
    for lang in AUTHORED_LANGS:
        if lang == "en":
            continue
        field[lang] = {"text": authored[lang][key], "translationStatus": "done"}
    return field


def build_localized_list(en_list, authored, key):
    out = []
    for i in range(len(en_list)):
        item = {"en": {"text": en_list[i], "translationStatus": "done"}}
        for lang in AUTHORED_LANGS:
            if lang == "en":
                continue
            item[lang] = {"text": authored[lang][key][i], "translationStatus": "done"}
        out.append(item)
    return out


def transform_question(q, overrides):
    authored = {lang: q[lang] for lang in AUTHORED_LANGS if lang in q}
    q_field = build_localized_field(q["en"]["q"], authored, "q")
    options_field = build_localized_list(q["en"]["options"], authored, "options")
    explanation_field = build_localized_field(q["en"]["explanation"], authored, "explanation")

    for lang in FALLBACK_LANGS:
        override = overrides.get(lang, {}).get(q["id"])
        if override:
            q_field[lang] = {"text": override["q"], "translationStatus": "done"}
            explanation_field[lang] = {"text": override["explanation"], "translationStatus": "done"}
            for i, opt in enumerate(override["options"]):
                options_field[i][lang] = {"text": opt, "translationStatus": "done"}
        else:
            q_field[lang] = {"text": q["en"]["q"], "translationStatus": "pending"}
            explanation_field[lang] = {"text": q["en"]["explanation"], "translationStatus": "pending"}
            for i, opt in enumerate(q["en"]["options"]):
                options_field[i][lang] = {"text": opt, "translationStatus": "pending"}

    return {
        "id": q["id"],
        "category": q["category"],
        "subcategory": q.get("subcategory"),
        "difficulty": q.get("difficulty", 1),
        "needsVerification": q.get("needsVerification", False),
        "q": q_field,
        "options": options_field,
        "answer": q["answer"],
        "explanation": explanation_field,
    }


def main():
    with open(os.path.join(CONTENT_DIR, "taxonomy.json"), encoding="utf-8") as f:
        taxonomy = json.load(f)

    overrides = load_overrides()

    questions = []
    for fname in sorted(os.listdir(BANK_DIR)):
        if not fname.endswith(".json"):
            continue
        with open(os.path.join(BANK_DIR, fname), encoding="utf-8") as f:
            data = json.load(f)
        for q in data["questions"]:
            questions.append(transform_question(q, overrides))

    bundle = {
        "version": 1,
        "languages": ALL_LANGS,
        "taxonomy": taxonomy,
        "questions": questions,
        "stats": {
            "totalQuestions": len(questions),
            "needsVerificationCount": sum(1 for q in questions if q["needsVerification"]),
            "byCategory": {},
        },
    }
    for q in questions:
        bundle["stats"]["byCategory"][q["category"]] = bundle["stats"]["byCategory"].get(q["category"], 0) + 1

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(bundle, f, ensure_ascii=False, indent=1)

    print(f"Bundle written to {OUT_PATH}")
    print(f"Total questions: {len(questions)}")
    print(f"needsVerification: {bundle['stats']['needsVerificationCount']}")
    for cat, count in bundle["stats"]["byCategory"].items():
        print(f"  {cat}: {count}")


if __name__ == "__main__":
    main()
