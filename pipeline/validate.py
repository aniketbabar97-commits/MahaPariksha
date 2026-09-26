"""Validate content files against the taxonomy and schema.

Usage: python pipeline/validate.py            # validate everything
       python pipeline/validate.py FILE...    # validate specific files
Exits non-zero on any error.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
DEVANAGARI = re.compile(r"[ऀ-ॿ]")

taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
TOPICS = {s["id"]: {t["id"] for t in s["topics"]} for s in taxonomy["subjects"]}

Q_FIELDS = {"id", "s", "t", "d", "q_mr", "q_en", "o_mr", "o_en", "a", "e_mr", "e_en"}
Q_OPTIONAL = {"hook_mr", "hook_en", "fact_mr", "fact_en", "src"}
F_FIELDS = {"id", "s", "t", "f_mr", "b_mr", "f_en", "b_en"}
M_FIELDS = {"id", "type", "mr", "en"}
M_OPTIONAL = {"by"}


def nonempty(v):
    return isinstance(v, str) and v.strip() != ""


def check_question(q, where, errs):
    keys = set(q)
    if not Q_FIELDS <= keys:
        errs.append(f"{where}: missing {sorted(Q_FIELDS - keys)}")
        return
    if keys - Q_FIELDS - Q_OPTIONAL:
        errs.append(f"{where}: unknown fields {sorted(keys - Q_FIELDS - Q_OPTIONAL)}")
    if q["s"] not in TOPICS or q["t"] not in TOPICS[q["s"]]:
        errs.append(f"{where}: bad subject/topic {q['s']}/{q['t']}")
    if q["d"] not in (1, 2, 3):
        errs.append(f"{where}: d must be 1,2,3")
    for lang in ("mr", "en"):
        opts = q[f"o_{lang}"]
        if not (isinstance(opts, list) and len(opts) == 4 and all(nonempty(o) for o in opts)):
            errs.append(f"{where}: o_{lang} must be 4 non-empty strings")
        elif len({o.strip() for o in opts}) != 4:
            errs.append(f"{where}: o_{lang} has duplicate options")
        for f in ("q", "e"):
            if not nonempty(q[f"{f}_{lang}"]):
                errs.append(f"{where}: {f}_{lang} empty")
    if not isinstance(q["a"], int) or not 0 <= q["a"] <= 3:
        errs.append(f"{where}: a must be 0..3")
    if nonempty(q.get("q_mr")) and not DEVANAGARI.search(q["q_mr"]) and q["s"] != "english":
        errs.append(f"{where}: q_mr has no Devanagari")


def check_flashcard(c, where, errs):
    keys = set(c)
    if keys != F_FIELDS:
        errs.append(f"{where}: fields must be {sorted(F_FIELDS)}, got {sorted(keys)}")
        return
    if c["s"] not in TOPICS or c["t"] not in TOPICS[c["s"]]:
        errs.append(f"{where}: bad subject/topic {c['s']}/{c['t']}")
    for f in ("f_mr", "b_mr", "f_en", "b_en"):
        if not nonempty(c[f]):
            errs.append(f"{where}: {f} empty")


def check_motivation(m, where, errs):
    keys = set(m)
    if not M_FIELDS <= keys or keys - M_FIELDS - M_OPTIONAL:
        errs.append(f"{where}: bad fields {sorted(keys)}")
        return
    if m["type"] not in ("quote", "story", "tip"):
        errs.append(f"{where}: type must be quote/story/tip")
    if not (nonempty(m["mr"]) and nonempty(m["en"])):
        errs.append(f"{where}: empty text")


def validate_file(path, seen_ids, errs):
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errs.append(f"{path}: invalid JSON: {e}")
        return 0
    if not isinstance(data, list):
        errs.append(f"{path}: top level must be a list")
        return 0
    kind = path.parent.name
    checker = {"bank": check_question, "flashcards": check_flashcard, "motivation": check_motivation}.get(kind)
    if checker is None:
        return 0
    for i, item in enumerate(data):
        where = f"{path.relative_to(ROOT)}[{i}]"
        if not isinstance(item, dict):
            errs.append(f"{where}: not an object")
            continue
        iid = item.get("id")
        if iid in seen_ids:
            errs.append(f"{where}: duplicate id {iid}")
        seen_ids.add(iid)
        checker(item, where, errs)
    return len(data)


def main(argv):
    files = [Path(a).resolve() for a in argv] or sorted(
        p for d in ("bank", "flashcards", "motivation") for p in (CONTENT / d).glob("*.json")
    )
    errs, seen, total = [], set(), 0
    for f in files:
        total += validate_file(f, seen, errs)
    for e in errs[:200]:
        print("ERROR", e)
    print(f"{len(files)} files, {total} items, {len(errs)} errors")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
