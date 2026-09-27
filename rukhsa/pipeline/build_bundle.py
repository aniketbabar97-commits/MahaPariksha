#!/usr/bin/env python3
"""
Builds rukhsa/app/assets/content/bundle.json from:
  - rukhsa/content/taxonomy.json
  - rukhsa/content/bank/*.json  (authored source, see author_bank.py)

For every question, this script:
  1. Keeps the authored "en" and "ar" text as-is (translationStatus: "done").
  2. Fills the remaining 8 languages (ur, hi, tl, ml, bn, ta, fa, fr) with the
     English text plus translationStatus: "pending", so the app can clearly
     mark/filter untranslated content instead of silently showing fake
     translations.

Run: python3 rukhsa/pipeline/build_bundle.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
CONTENT_DIR = os.path.join(ROOT, "content")
BANK_DIR = os.path.join(CONTENT_DIR, "bank")
OUT_PATH = os.path.join(ROOT, "app", "assets", "content", "bundle.json")

FALLBACK_LANGS = ["ur", "hi", "tl", "ml", "bn", "ta", "fa", "fr"]
AUTHORED_LANGS = ["en", "ar"]
ALL_LANGS = AUTHORED_LANGS + FALLBACK_LANGS


def build_localized_field(en_value, ar_value):
    field = {
        "en": {"text": en_value, "translationStatus": "done"},
        "ar": {"text": ar_value, "translationStatus": "done"},
    }
    for lang in FALLBACK_LANGS:
        field[lang] = {"text": en_value, "translationStatus": "pending"}
    return field


def build_localized_list(en_list, ar_list):
    out = []
    for i in range(len(en_list)):
        out.append(build_localized_field(en_list[i], ar_list[i]))
    return out


def transform_question(q):
    return {
        "id": q["id"],
        "category": q["category"],
        "subcategory": q.get("subcategory"),
        "difficulty": q.get("difficulty", 1),
        "needsVerification": q.get("needsVerification", False),
        "q": build_localized_field(q["en"]["q"], q["ar"]["q"]),
        "options": build_localized_list(q["en"]["options"], q["ar"]["options"]),
        "answer": q["answer"],
        "explanation": build_localized_field(q["en"]["explanation"], q["ar"]["explanation"]),
    }


def main():
    with open(os.path.join(CONTENT_DIR, "taxonomy.json"), encoding="utf-8") as f:
        taxonomy = json.load(f)

    questions = []
    for fname in sorted(os.listdir(BANK_DIR)):
        if not fname.endswith(".json"):
            continue
        with open(os.path.join(BANK_DIR, fname), encoding="utf-8") as f:
            data = json.load(f)
        for q in data["questions"]:
            questions.append(transform_question(q))

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
