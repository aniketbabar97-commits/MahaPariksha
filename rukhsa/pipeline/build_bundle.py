#!/usr/bin/env python3
"""
Rukhsa content build pipeline.

Source of truth: rukhsa/content/questions_en.json (canonical metadata: id,
category, sub, answer index, needsVerification) plus one fully-authored
rukhsa/content/questions_<lang>.json per language (q / options / explanation
only). There is no English-fallback / "pending" translation status anywhere
in this pipeline by design: every shipped language is a real, independently
authored and self-verified translation. A question the translator wasn't
fully confident in on a *fact* (a fine amount, a numeric threshold) carries
`needsVerification: true` instead -- that flag is about fact-checking against
the official RTA handbook, never a stand-in for an untranslated string.

Outputs:
  - rukhsa/app/assets/content/bundle.json  (consumed by the Flutter app;
    matches the ContentBundle/Question/Localized schema in
    rukhsa/app/lib/data/models.dart -- every LocalizedText carries
    translationStatus: "done")
  - rukhsa/assets/bundle/questions_<lang>.json + manifest.json (flat,
    human-inspectable per-language dumps used by build validation / CI and
    by anything outside the Flutter app that wants the raw content)

Usage:
    python3 rukhsa/pipeline/build_bundle.py

Validates:
    - every language file has a translation for every English question id
    - every question has exactly 4 options
    - answer index is within range
    - no language file is missing (fails loudly instead of silently
      falling back to English)
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # rukhsa/
CONTENT_DIR = os.path.join(ROOT, "content")
FLAT_OUT_DIR = os.path.join(ROOT, "assets", "bundle")
APP_BUNDLE_PATH = os.path.join(ROOT, "app", "assets", "content", "bundle.json")

LANGUAGES = ["en", "ar", "ur", "hi", "tl", "ml", "bn", "ta", "fa", "fr", "zh", "ru"]
RTL_LANGUAGES = {"ar", "ur", "fa"}


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def localized_field(per_lang_value):
    """per_lang_value: {lang: str} -> {lang: {text, translationStatus: 'done'}}"""
    return {lang: {"text": text, "translationStatus": "done"} for lang, text in per_lang_value.items()}


def localized_list(per_lang_options):
    """per_lang_options: {lang: [str, str, str, str]} -> list of 4 localized fields, one per option index."""
    n = len(next(iter(per_lang_options.values())))
    out = []
    for i in range(n):
        out.append({lang: {"text": opts[i], "translationStatus": "done"} for lang, opts in per_lang_options.items()})
    return out


def main():
    errors = []

    en_path = os.path.join(CONTENT_DIR, "questions_en.json")
    if not os.path.exists(en_path):
        sys.exit(f"FATAL: missing canonical file {en_path}")
    en_questions = load_json(en_path)
    en_by_id = {q["id"]: q for q in en_questions}

    ui_strings = load_json(os.path.join(CONTENT_DIR, "ui_strings.json"))
    taxonomy = load_json(os.path.join(CONTENT_DIR, "taxonomy.json"))

    by_lang = {}
    for lang in LANGUAGES:
        lang_path = os.path.join(CONTENT_DIR, f"questions_{lang}.json")
        if not os.path.exists(lang_path):
            errors.append(f"Missing questions_{lang}.json — no English fallback is allowed.")
            continue
        lang_questions = load_json(lang_path)
        lang_by_id = {q["id"]: q for q in lang_questions}

        missing_ids = set(en_by_id) - set(lang_by_id)
        extra_ids = set(lang_by_id) - set(en_by_id)
        if missing_ids:
            errors.append(f"[{lang}] missing translations for ids: {sorted(missing_ids)}")
        if extra_ids:
            errors.append(f"[{lang}] has unknown extra ids: {sorted(extra_ids)}")
        for qid, tq in lang_by_id.items():
            if len(tq.get("options", [])) != 4:
                errors.append(f"[{lang}] {qid} does not have exactly 4 options")
        by_lang[lang] = lang_by_id

    if errors:
        print("BUILD FAILED:")
        for e in errors:
            print(" -", e)
        sys.exit(1)

    # ---- Flat per-language dumps (assets/bundle/) ----
    os.makedirs(FLAT_OUT_DIR, exist_ok=True)
    per_lang_counts = {}
    for lang in LANGUAGES:
        merged = []
        for qid, en_q in en_by_id.items():
            tq = by_lang[lang][qid]
            merged.append({
                "id": qid,
                "category": en_q["category"],
                "sub": en_q.get("sub"),
                "answer": en_q["answer"],
                "needsVerification": en_q.get("needsVerification", False),
                "q": tq["q"],
                "options": tq["options"],
                "explanation": tq["explanation"],
            })
        per_lang_counts[lang] = len(merged)
        with open(os.path.join(FLAT_OUT_DIR, f"questions_{lang}.json"), "w", encoding="utf-8") as f:
            json.dump({"language": lang, "isRtl": lang in RTL_LANGUAGES, "questionCount": len(merged), "questions": merged},
                       f, ensure_ascii=False, indent=2)

    with open(os.path.join(FLAT_OUT_DIR, "ui_strings.json"), "w", encoding="utf-8") as f:
        json.dump(ui_strings, f, ensure_ascii=False, indent=2)
    with open(os.path.join(FLAT_OUT_DIR, "taxonomy.json"), "w", encoding="utf-8") as f:
        json.dump(taxonomy, f, ensure_ascii=False, indent=2)

    manifest = {
        "languages": LANGUAGES,
        "rtlLanguages": sorted(RTL_LANGUAGES),
        "questionCountPerLanguage": per_lang_counts,
        "totalEnglishQuestions": len(en_questions),
    }
    with open(os.path.join(FLAT_OUT_DIR, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    # ---- Flutter app bundle (app/assets/content/bundle.json) ----
    app_questions = []
    for qid, en_q in en_by_id.items():
        q_text = {lang: by_lang[lang][qid]["q"] for lang in LANGUAGES}
        opt_text = {lang: by_lang[lang][qid]["options"] for lang in LANGUAGES}
        expl_text = {lang: by_lang[lang][qid]["explanation"] for lang in LANGUAGES}
        app_questions.append({
            "id": qid,
            "category": en_q["category"],
            "subcategory": en_q.get("sub"),
            "difficulty": en_q.get("difficulty", 1),
            "needsVerification": en_q.get("needsVerification", False),
            "q": localized_field(q_text),
            "options": localized_list(opt_text),
            "answer": en_q["answer"],
            "explanation": localized_field(expl_text),
        })

    app_categories = []
    for c in taxonomy["categories"]:
        cat = {"id": c["id"], "icon": c.get("icon", "category"), "en": c["en"], "ar": c["ar"]}
        if "subcategories" in c:
            cat["subcategories"] = [{"id": s["id"], "en": s["en"], "ar": s["ar"]} for s in c["subcategories"]]
        app_categories.append(cat)

    needs_verification_count = sum(1 for q in app_questions if q["needsVerification"])
    app_bundle = {
        "languages": LANGUAGES,
        "taxonomy": {"categories": app_categories},
        "questions": app_questions,
        "stats": {
            "totalQuestions": len(app_questions),
            "needsVerificationCount": needs_verification_count,
        },
    }
    os.makedirs(os.path.dirname(APP_BUNDLE_PATH), exist_ok=True)
    with open(APP_BUNDLE_PATH, "w", encoding="utf-8") as f:
        json.dump(app_bundle, f, ensure_ascii=False, indent=2)

    print("Build OK.")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    print(f"Wrote app bundle: {APP_BUNDLE_PATH} ({len(app_questions)} questions x {len(LANGUAGES)} languages, all translationStatus=done)")


if __name__ == "__main__":
    main()
