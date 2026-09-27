#!/usr/bin/env python3
"""Validates the built bundle.json for structural correctness."""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
BUNDLE_PATH = os.path.join(ROOT, "app", "assets", "content", "bundle.json")
EXPECTED_LANGS = {"en", "ar", "ur", "hi", "tl", "ml", "bn", "ta", "fa", "fr", "zh", "ru"}


def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)


def main():
    if not os.path.exists(BUNDLE_PATH):
        fail(f"bundle not found at {BUNDLE_PATH}. Run build_bundle.py first.")

    with open(BUNDLE_PATH, encoding="utf-8") as f:
        bundle = json.load(f)

    if set(bundle["languages"]) != EXPECTED_LANGS:
        fail(f"language set mismatch: {bundle['languages']}")

    ids = set()
    valid_categories = {c["id"] for c in bundle["taxonomy"]["categories"]}
    n = len(bundle["questions"])
    if not (60 <= n <= 100):
        print(f"WARN: question count {n} outside the 60-80 target range")

    for q in bundle["questions"]:
        if q["id"] in ids:
            fail(f"duplicate question id {q['id']}")
        ids.add(q["id"])

        if q["category"] not in valid_categories:
            fail(f"{q['id']}: unknown category {q['category']}")

        if not isinstance(q["answer"], int) or not (0 <= q["answer"] < 4):
            fail(f"{q['id']}: answer index must be 0-3, got {q['answer']}")

        if len(q["options"]) != 4:
            fail(f"{q['id']}: must have exactly 4 options, got {len(q['options'])}")

        for field_name in ["q", "explanation"]:
            field = q[field_name]
            if set(field.keys()) != EXPECTED_LANGS:
                fail(f"{q['id']}.{field_name}: missing languages {EXPECTED_LANGS - set(field.keys())}")
            for lang, val in field.items():
                if not val.get("text"):
                    fail(f"{q['id']}.{field_name}.{lang}: empty text")
                if val.get("translationStatus") != "done":
                    fail(f"{q['id']}.{field_name}.{lang}: translationStatus must be 'done' (got {val.get('translationStatus')!r})")

        for opt in q["options"]:
            if set(opt.keys()) != EXPECTED_LANGS:
                fail(f"{q['id']}: option missing languages")

        # No English-fallback content ships: every language must be a real,
        # authored translation (translationStatus == "done"), never "pending".
        for lang in EXPECTED_LANGS:
            if q["q"][lang]["translationStatus"] != "done":
                fail(f"{q['id']}.q.{lang}: must be translationStatus=done (no pending fallback allowed)")
            if q["explanation"][lang]["translationStatus"] != "done":
                fail(f"{q['id']}.explanation.{lang}: must be translationStatus=done (no pending fallback allowed)")
            for opt in q["options"]:
                if opt[lang]["translationStatus"] != "done":
                    fail(f"{q['id']}: option.{lang} must be translationStatus=done (no pending fallback allowed)")

    print(f"OK: {n} questions, {len(valid_categories)} categories, "
          f"{bundle['stats']['needsVerificationCount']} flagged needsVerification.")


if __name__ == "__main__":
    main()
