"""Validate content files against the taxonomy and schema.

Usage: python pipeline/validate.py            # validate everything
       python pipeline/validate.py FILE...    # validate specific files
Exits non-zero on any error.
"""
import fcntl
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
DEVANAGARI = re.compile(r"[ऀ-ॿ]")
ISO_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
TOPICS = {s["id"]: {t["id"] for t in s["topics"]} for s in taxonomy["subjects"]}
EXAM_IDS = {e["id"] for e in taxonomy["exams"]}

Q_FIELDS = {"id", "s", "t", "d", "q_hi", "q_en", "o_hi", "o_en", "a", "e_hi", "e_en"}
Q_OPTIONAL = {"hook_hi", "hook_en", "fact_hi", "fact_en", "src", "date"}
F_FIELDS = {"id", "s", "t", "f_hi", "b_hi", "f_en", "b_en"}
M_FIELDS = {"id", "type", "hi", "en"}
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
    for lang in ("hi", "en"):
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
    if nonempty(q.get("q_hi")) and not DEVANAGARI.search(q["q_hi"]) and q["s"] != "english":
        errs.append(f"{where}: q_hi has no Devanagari")
    if "date" in q and not (isinstance(q["date"], str) and ISO_DATE.match(q["date"])):
        errs.append(f"{where}: date must be YYYY-MM-DD")


def check_flashcard(c, where, errs):
    keys = set(c)
    if keys != F_FIELDS:
        errs.append(f"{where}: fields must be {sorted(F_FIELDS)}, got {sorted(keys)}")
        return
    if c["s"] not in TOPICS or c["t"] not in TOPICS[c["s"]]:
        errs.append(f"{where}: bad subject/topic {c['s']}/{c['t']}")
    for f in ("f_hi", "b_hi", "f_en", "b_en"):
        if not nonempty(c[f]):
            errs.append(f"{where}: {f} empty")


def check_motivation(m, where, errs):
    keys = set(m)
    if not M_FIELDS <= keys or keys - M_FIELDS - M_OPTIONAL:
        errs.append(f"{where}: bad fields {sorted(keys)}")
        return
    if m["type"] not in ("quote", "story", "tip"):
        errs.append(f"{where}: type must be quote/story/tip")
    if not (nonempty(m["hi"]) and nonempty(m["en"])):
        errs.append(f"{where}: empty text")


def check_map(node, where, errs, depth=0):
    if not (isinstance(node, dict) and nonempty(node.get("hi")) and nonempty(node.get("en"))):
        errs.append(f"{where}: mind-map node needs hi/en")
        return
    if depth > 4:
        errs.append(f"{where}: mind map deeper than 4 levels")
    for c in node.get("children", []):
        check_map(c, where, errs, depth + 1)


def check_cheat_sheet(c, where, errs):
    need = {"id", "s", "t", "cat_hi", "cat_en", "items_hi", "items_en"}
    if not need <= set(c):
        errs.append(f"{where}: missing {sorted(need - set(c))}")
        return
    if c["s"] not in TOPICS or c["t"] not in TOPICS[c["s"]]:
        errs.append(f"{where}: bad subject/topic {c['s']}/{c['t']}")
    if not (nonempty(c["cat_hi"]) and nonempty(c["cat_en"])):
        errs.append(f"{where}: empty category title")
    ih, ie = c["items_hi"], c["items_en"]
    if not (isinstance(ih, list) and isinstance(ie, list) and len(ih) == len(ie)
            and 1 <= len(ih) <= 30 and all(nonempty(x) for x in ih) and all(nonempty(x) for x in ie)):
        errs.append(f"{where}: items_hi/items_en must be parallel lists of 1-30 non-empty strings")


def check_note(n, where, errs):
    need = {"id", "s", "t", "summary_hi", "summary_en", "facts_hi", "facts_en", "map"}
    if not need <= set(n):
        errs.append(f"{where}: missing {sorted(need - set(n))}")
        return
    if n["s"] not in TOPICS or n["t"] not in TOPICS[n["s"]]:
        errs.append(f"{where}: bad subject/topic {n['s']}/{n['t']}")
    if not (nonempty(n["summary_hi"]) and nonempty(n["summary_en"])):
        errs.append(f"{where}: empty summary")
    fh, fe = n["facts_hi"], n["facts_en"]
    if not (isinstance(fh, list) and isinstance(fe, list) and len(fh) == len(fe) and 5 <= len(fh) <= 15):
        errs.append(f"{where}: facts_hi/facts_en must be parallel lists of 5-15")
    if "tips_hi" in n or "tips_en" in n:
        th, te = n.get("tips_hi"), n.get("tips_en")
        if not (isinstance(th, list) and isinstance(te, list) and len(th) == len(te) and 3 <= len(th) <= 6):
            errs.append(f"{where}: tips_hi/tips_en must be parallel lists of 3-6")
    check_map(n["map"], where, errs)


def resolve_exam_strategy(data):
    """Resolve {"$ref": "other_exam_id"} entries (used by exams that share an
    identical selection process, e.g. RRB JE's three engineering branches) into
    a copy of the referenced exam's content."""
    resolved = {}
    for exam_id, entry in data.items():
        ref = entry.get("$ref") if isinstance(entry, dict) else None
        resolved[exam_id] = data[ref] if ref else entry
    return resolved


def check_exam_strategy(data, path, errs):
    """content/exam_strategy.json is a single dict keyed by exam id (not a list
    of items like bank/flashcards/motivation/notes), so it's validated separately
    from validate_file's per-item loop."""
    where = path.relative_to(ROOT)
    missing = EXAM_IDS - set(data)
    if missing:
        errs.append(f"{where}: missing exam ids {sorted(missing)}")
    extra = set(data) - EXAM_IDS
    if extra:
        errs.append(f"{where}: unknown exam ids {sorted(extra)}")
    for exam_id, entry in data.items():
        if isinstance(entry, dict) and "$ref" in entry:
            if entry["$ref"] not in data:
                errs.append(f"{where}[{exam_id}]: $ref to unknown exam {entry['$ref']}")
            continue
        need = {"stages", "tips", "cutoff_hi", "cutoff_en"}
        if not isinstance(entry, dict) or not need <= set(entry):
            errs.append(f"{where}[{exam_id}]: missing {sorted(need - set(entry if isinstance(entry, dict) else {}))}")
            continue
        if not (nonempty(entry["cutoff_hi"]) and nonempty(entry["cutoff_en"])):
            errs.append(f"{where}[{exam_id}]: empty cutoff text")
        stages = entry["stages"]
        if not (isinstance(stages, list) and 2 <= len(stages) <= 6):
            errs.append(f"{where}[{exam_id}]: stages must be a list of 2-6")
        else:
            for i, s in enumerate(stages):
                need_s = {"hi", "en", "detail_hi", "detail_en"}
                if not (isinstance(s, dict) and need_s <= set(s) and all(nonempty(s[k]) for k in need_s)):
                    errs.append(f"{where}[{exam_id}].stages[{i}]: needs non-empty {sorted(need_s)}")
        tips = entry["tips"]
        if not (isinstance(tips, list) and 3 <= len(tips) <= 5):
            errs.append(f"{where}[{exam_id}]: tips must be a list of 3-5")
        else:
            for i, t in enumerate(tips):
                if not (isinstance(t, dict) and nonempty(t.get("hi")) and nonempty(t.get("en"))):
                    errs.append(f"{where}[{exam_id}].tips[{i}]: needs non-empty hi/en")


def validate_file(path, seen_ids, errs):
    try:
        # Shared lock so a concurrent content_gen writer (which takes an exclusive
        # lock in bulk_questions.py's flush()) can't be read mid-write -- a plain
        # read here could otherwise see a truncated file and report a false
        # "invalid JSON" error for a file that's actually fine on disk.
        with open(path, encoding="utf-8") as f:
            fcntl.flock(f, fcntl.LOCK_SH)
            text = f.read()
            fcntl.flock(f, fcntl.LOCK_UN)
        data = json.loads(text)
    except json.JSONDecodeError as e:
        errs.append(f"{path}: invalid JSON: {e}")
        return 0
    if not isinstance(data, list):
        errs.append(f"{path}: top level must be a list")
        return 0
    kind = path.parent.name
    checker = {"bank": check_question, "flashcards": check_flashcard, "motivation": check_motivation,
               "notes": check_note, "cheat_sheets": check_cheat_sheet}.get(kind)
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


def check_gk_booster(path, errs):
    """content/gk_booster.json isn't a per-item collection like bank/flashcards/etc
    (it's a single file of category -> items), so it's validated on its own shape
    here rather than via validate_file's per-directory checker dispatch."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        errs.append(f"{path}: invalid JSON: {e}")
        return 0
    if not (isinstance(data, dict) and isinstance(data.get("categories"), list)):
        errs.append(f"{path}: top level must be an object with a 'categories' list")
        return 0
    total = 0
    seen_cat_ids = set()
    for ci, cat in enumerate(data["categories"]):
        where = f"{path.relative_to(ROOT)}.categories[{ci}]"
        need = {"id", "icon", "name_hi", "name_en", "items"}
        if not isinstance(cat, dict) or not need <= set(cat):
            errs.append(f"{where}: missing {sorted(need - set(cat if isinstance(cat, dict) else {}))}")
            continue
        if cat["id"] in seen_cat_ids:
            errs.append(f"{where}: duplicate category id {cat['id']}")
        seen_cat_ids.add(cat["id"])
        if not (nonempty(cat["name_hi"]) and nonempty(cat["name_en"])):
            errs.append(f"{where}: empty category name")
        if not isinstance(cat["items"], list) or not cat["items"]:
            errs.append(f"{where}: items must be a non-empty list")
            continue
        for ii, item in enumerate(cat["items"]):
            iwhere = f"{where}.items[{ii}]"
            ineed = {"title_hi", "title_en", "detail_hi", "detail_en"}
            if not isinstance(item, dict) or not ineed <= set(item):
                errs.append(f"{iwhere}: missing {sorted(ineed - set(item if isinstance(item, dict) else {}))}")
                continue
            for f in ineed:
                if not nonempty(item[f]):
                    errs.append(f"{iwhere}: {f} empty")
            total += 1
    return total


def main(argv):
    explicit = [Path(a).resolve() for a in argv]
    files = explicit or sorted(
        p for d in ("bank", "flashcards", "motivation", "notes", "cheat_sheets") for p in (CONTENT / d).glob("*.json")
    )
    errs, seen, total = [], set(), 0
    for f in files:
        total += validate_file(f, seen, errs)

    strategy_path = CONTENT / "exam_strategy.json"
    if not explicit or strategy_path.resolve() in explicit:
        strategy = json.loads(strategy_path.read_text(encoding="utf-8"))
        check_exam_strategy(strategy, strategy_path, errs)
        total += len(strategy)
        files = files + [strategy_path] if strategy_path not in files else files

    gk_booster_path = CONTENT / "gk_booster.json"
    if not argv and gk_booster_path.exists():
        files.append(gk_booster_path)
        total += check_gk_booster(gk_booster_path, errs)

    for e in errs[:200]:
        print("ERROR", e)
    print(f"{len(files)} files, {total} items, {len(errs)} errors")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
