"""Normalize previous-year-question (PYQ) sources into one staging format.

Sources (clone them anywhere, pass the paths in):
  --rrb-je  github.com/bhaskar701/RRB-JE      real RRB JE CBT-1 2024 + 2025 papers
  --ssc     github.com/akarohitmishra/ssc-all-exam   SSC Tier-I/pre papers 2019-2026

Writes pipeline/pyq/staging/<source>.jsonl, one object per question:
  {"sid", "exam", "label", "year", "subj", "topic_hint", "q", "o": [4], "a": 0..3}
Only the official question, options and answer key are kept -- the sources'
own solutions are dropped; enrich.py writes fresh bilingual explanations.

Filters out anything that can't stand on its own as text: image/figure
questions, items whose options were lost in PDF extraction, duplicate or empty
options, and (for GK) questions tied to a specific year's current events.
"""
import argparse
import json
import random
import re
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
STAGING = HERE / "staging"

IMAGE = re.compile(r"\[IMAGE|\bfigure\b|\bdiagram\b|\bgiven (?:image|picture)|\bimage\b|\bshown below\b", re.I)
# GK whose answer depends on when it was asked ("recently", "in 2023 ...") -- these
# age out, and the app keeps current affairs in its own dated pipeline instead.
DATED = re.compile(r"\b(recent(ly)?|current(ly)?|this year|latest|20(1[5-9]|2\d))\b", re.I)


def norm(s):
    return re.sub(r"[^a-z0-9]+", "", s.lower())


def clean(s):
    s = s.replace(" ", " ")
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\n{2,}", "\n", s)
    return s.strip()


def fmt_date(s):
    """'2025-12-11' / '12 April 2022' / '12 Apr 2022' -> '11 Dec 2025'."""
    if not s:
        return ""
    for f in ("%Y-%m-%d", "%d %B %Y", "%d %b %Y", "%d %b, %Y", "%d %B, %Y"):
        try:
            d = datetime.strptime(s.strip(), f)
            return f"{d.day} {d.strftime('%b %Y')}"
        except ValueError:
            pass
    return s.strip()


def ok_options(opts):
    return (len(opts) == 4 and all(o.strip() for o in opts)
            and len({norm(o) or o.strip() for o in opts}) == 4
            and not any(IMAGE.search(o) for o in opts))


JE_SUBJ = {"numerical": "maths", "reasoning": "reasoning", "science": "science"}


def rrb_je(root):
    data = json.loads((Path(root) / "data/questions.json").read_text(encoding="utf-8"))["sections"]
    out, seen = [], set()
    for section, items in data.items():
        for i, x in enumerate(items):
            q, opts = clean(x.get("q", "")), [clean(o) for o in x.get("o", [])]
            if not q or q.startswith("Ans ") or "Correct Answer:" in q or IMAGE.search(q) or not ok_options(opts):
                continue
            if x.get("a") not in ("A", "B", "C", "D"):
                continue
            key = norm(q) + "|" + "|".join(sorted(norm(o) for o in opts))
            if key in seen:
                continue
            seen.add(key)
            year = int(x["year"])
            label = f"RRB JE CBT-1 {year}"
            m = re.match(r"(\d{2})/(\d{2})/(\d{4})", x.get("date") or "")
            if m:
                d = datetime(int(m[3]), int(m[2]), int(m[1]))
                label += f" · {d.day} {d.strftime('%b %Y')}"
                if x.get("shift"):
                    label += f" · Shift {x['shift']}"
            out.append({
                "sid": f"rrbje-{section}-{i}", "exam": "RRB JE", "label": label, "year": year,
                "subj": JE_SUBJ[section], "topic_hint": x.get("label") or x.get("topic", ""),
                "q": q, "o": opts, "a": "ABCD".index(x["a"]),
            })
    return out


SSC_SUBJ = {"MATH": "maths", "REAS": "reasoning", "GK": "gk", "ENG": "english"}
SSC_NAME = {"SSC-CGL": "SSC CGL", "SSC-CHSL": "SSC CHSL", "SSC-MTS": "SSC MTS", "SSC-GD": "SSC GD",
            "SSC-CPO": "SSC CPO", "SSC-Selection-Post": "SSC Selection Post"}
# English is a minor subject for railway exams (only some RRB papers have it), so it
# gets a smaller share than the core sections.
SSC_QUOTA = {"maths": 1000, "reasoning": 1000, "gk": 1200, "english": 400}


def ssc(root, years, seed=7):
    base = Path(root) / "subjectwise-db"
    pools = {s: [] for s in SSC_QUOTA}
    seen = set()
    for exam, name in SSC_NAME.items():
        for code, subj in SSC_SUBJ.items():
            f = base / exam / "pre" / code / "questions.jsonl"
            if not f.exists():
                continue
            for line in f.open(encoding="utf-8"):
                x = json.loads(line)
                if int(x["year"]) not in years or x.get("type", "mcq") != "mcq":
                    continue
                q = clean(x["question"])
                opts = [clean(o["text"]) for o in x["options"]]
                labels = [o["label"] for o in x["options"]]
                if (not q or len(q) > 700 or IMAGE.search(q) or not ok_options(opts)
                        or x["correct"] not in labels):
                    continue
                if subj == "gk" and DATED.search(q + " " + " ".join(opts)):
                    continue
                key = norm(q) + "|" + "|".join(sorted(norm(o) for o in opts))
                if key in seen:
                    continue
                seen.add(key)
                label = f"{name} {x['year']}"
                held = fmt_date(x.get("held_on") or x.get("paper_meta", {}).get("held_on"))
                if held:
                    label += f" · {held}"
                if x.get("shift"):
                    label += f" · Shift {x['shift']}"
                pools[subj].append({
                    "sid": f"ssc-{x['qid']}", "exam": name, "label": label, "year": int(x["year"]),
                    "subj": subj, "topic_hint": x.get("source_concept") or x.get("chapter") or "",
                    "q": q, "o": opts, "a": labels.index(x["correct"]),
                })
    rng = random.Random(seed)
    out = []
    for subj, pool in pools.items():
        # Round-robin across exams so no single exam's papers crowd out the rest.
        by_exam = {}
        for r in pool:
            by_exam.setdefault(r["exam"], []).append(r)
        for rows in by_exam.values():
            rng.shuffle(rows)
        picked, queues = [], list(by_exam.values())
        while len(picked) < SSC_QUOTA[subj] and any(queues):
            for qu in queues:
                if qu and len(picked) < SSC_QUOTA[subj]:
                    picked.append(qu.pop())
        out.extend(picked)
        print(f"  ssc {subj}: {len(pool)} usable, kept {min(len(pool), SSC_QUOTA[subj])}")
    return out


def write(name, rows):
    STAGING.mkdir(parents=True, exist_ok=True)
    with (STAGING / f"{name}.jsonl").open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"{name}: {len(rows)} questions -> {STAGING / name}.jsonl")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--rrb-je")
    ap.add_argument("--ssc")
    ap.add_argument("--ssc-years", default="2023,2024,2025")
    args = ap.parse_args()
    if args.rrb_je:
        write("rrb_je", rrb_je(args.rrb_je))
    if args.ssc:
        write("ssc", ssc(args.ssc, {int(y) for y in args.ssc_years.split(",")}))
