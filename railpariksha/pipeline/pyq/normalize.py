"""Import previous-year questions (PYQs) from public GitHub datasets.

Sources (clone them anywhere, pass the paths in):
  --rrb-je  github.com/bhaskar701/RRB-JE              real RRB JE CBT-1 2024 + 2025 papers
  --ssc     github.com/akarohitmishra/ssc-all-exam    SSC Tier-I / pre papers

RRB JE ships with no explanations, so it is staged to pipeline/pyq/staging/rrb_je.jsonl
and written to content/pyq/rrb_je.json with an answer-only explanation for now.
SSC ships with solutions, which become the explanations (content/pyq/ssc_<exam>.json).

Both sources are English-only. Items carry English text only (no *_hi fields); the
app falls back to English for them. Every item gets a "pyq" label naming the paper
("SSC CGL 2024 · 17 Sep 2024 · Shift 2").

Only syllabus shared with railway exams is kept (maths, reasoning, GK / science --
no SSC English, which no RRB/RPF paper has). Dropped: image/figure questions, items
whose options were lost in extraction, duplicate/empty options, and GK tied to one
year's current events (it ages out; the app has a dated current-affairs pipeline).
"""
import argparse
import json
import random
import re
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
STAGING = HERE / "staging"

IMAGE = re.compile(r"\[IMAGE|\bfigures?\b|\bdiagram\b|\bgiven (?:image|picture)|\bimage\b|\bshown below\b"
                   r"|\bgiven below\b.*\bfigure|\bvenn\b|\bmirror\b|\bwater image\b|\bdice\b|\bcube\b", re.I)
# Leftover LaTeX from the source's math rendering ("frac{2)/(3)", "divleft{") -- unreadable as text.
LATEX = re.compile(r"frac\{|\bdiv(?:\b|left)|\bleft[{(\[]|right[})\]]|\\[a-z]+|sqrt\{|\^\{|_\{|\bcdot\b|\btimes\{")
DATED = re.compile(r"\b(recent(ly)?|current(ly)?|this year|latest|20(1[5-9]|2\d))\b", re.I)


def norm(s):
    return re.sub(r"[^a-z0-9]+", "", s.lower())


def clean(s):
    s = s.replace(" ", " ").replace("\\%", "%").replace("\\$", "$")
    # The source writes fractions as "5(1)/(4)" / "(1)/(4)"; print them as "5 1/4" / "1/4".
    s = re.sub(r"(\d)\((\d+)\)/\((\d+)\)", r"\1 \2/\3", s)
    s = re.sub(r"\((\d+)\)/\((\d+)\)", r"\1/\2", s)
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r" *\n *", "\n", s)
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


def key(q, opts):
    return norm(q) + "|" + "|".join(sorted(norm(o) for o in opts))


# ---------------------------------------------------------------- RRB JE

JE_SUBJ = {"numerical": "maths", "reasoning": "reasoning", "science": "science"}


def rrb_je(root):
    data = json.loads((Path(root) / "data/questions.json").read_text(encoding="utf-8"))["sections"]
    out, seen = [], set()
    for section, items in data.items():
        for i, x in enumerate(items):
            q, opts = clean(x.get("q", "")), [clean(o) for o in x.get("o", [])]
            if not q or q.startswith("Ans ") or "Correct Answer:" in q or IMAGE.search(q) or not ok_options(opts):
                continue
            if x.get("a") not in ("A", "B", "C", "D") or key(q, opts) in seen:
                continue
            seen.add(key(q, opts))
            year = int(x["year"])
            label = f"RRB JE CBT-1 {year}"
            m = re.match(r"(\d{2})/(\d{2})/(\d{4})", x.get("date") or "")
            if m:
                label += f" · {fmt_date(f'{m[3]}-{m[2]}-{m[1]}')}"
                if x.get("shift"):
                    label += f" · Shift {x['shift']}"
            out.append({
                "sid": f"rrbje-{section}-{i}", "exam": "RRB JE", "label": label, "year": year,
                "subj": JE_SUBJ[section], "topic_hint": x.get("label") or x.get("topic", ""),
                "q": q, "o": opts, "a": "ABCD".index(x["a"]),
            })
    return out


# ---------------------------------------------------------------- SSC

SSC_NAME = {"SSC-CGL": "SSC CGL", "SSC-CHSL": "SSC CHSL", "SSC-MTS": "SSC MTS", "SSC-GD": "SSC GD",
            "SSC-CPO": "SSC CPO", "SSC-Selection-Post": "SSC Selection Post"}

# SSC chapter -> (subject, topic) in content/taxonomy.json. None = drop (doesn't fit
# the railway syllabus, ages out, or is almost always figure-based).
CHAPTERS = {
    "MATH": {
        "profit-and-loss": "profit_loss", "discount": "profit_loss", "partnership": "profit_loss",
        "data-interpretation": "data_interpretation", "data-interpretation-old": "data_interpretation",
        "elementary-statistics": "data_interpretation", "statistics": "data_interpretation",
        "mensuration-2d": "mensuration", "mensuration-3d": "mensuration",
        "simplification": "decimal_fraction", "number-system": "number_system", "surds-and-indices": "number_system",
        "quantitative-aptitude": "number_system", "hcf-and-lcm": "hcf_lcm",
        "geometry": "geometry", "quadrilaterals-and-polygons": "geometry", "coordinate-geometry": "geometry",
        "time-and-work": "time_work", "pipe-and-cistern": "time_work",
        "average": "average", "age": "ratio_proportion", "proportion": "ratio_proportion",
        "mixture-and-alligation": "ratio_proportion",
        "time-and-distance": "time_speed_distance", "train": "time_speed_distance",
        "boat-and-stream": "time_speed_distance", "race-and-circular-motion": "time_speed_distance",
        "percentage": "percentage", "trigonometry": "trigonometry", "height-and-distance": "trigonometry",
        "algebra": "algebra", "simple-interest": "si_ci", "compound-interest": "si_ci",
    },
    "REAS": {
        "series": "series", "missing-number": "series", "analogy": "analogy", "similarity-and-differences": "analogy",
        "coding-decoding": "coding_decoding", "classification-odd-one-out": "classification",
        "alphabet-test": "alphabet_test", "word-dictionary-order": "alphabet_test",
        "seating-arrangement": "puzzle_seating", "puzzle-subtypes-not-to-miss": "puzzle_seating",
        "ranking-order": "puzzle_seating", "clock-and-calendar": "puzzle_seating", "calendar": "puzzle_seating",
        "blood-relations": "blood_relations", "direction-sense": "direction_sense",
        "syllogism": "syllogism", "logical-reasoning": "statement_conclusion",
        "logical-statement-questions": "statement_conclusion", "cause-and-effect": "statement_conclusion",
        "mathematical-operations": "mathematical_operations", "number-digit-operations": "mathematical_operations",
        "miscellaneous-other-possibilities": "mathematical_operations",
    },
    "GK": {
        "art-and-culture": ("gk", "indian_culture"), "indian-polity-and-constitution": ("gk", "indian_polity"),
        "sports-static-gk": ("gk", "sports_gk"), "indian-geography": ("gk", "indian_geography"),
        "indian-rivers": ("gk", "indian_geography"), "indian-climate": ("gk", "indian_geography"),
        "agriculture": ("gk", "indian_geography"), "indian-economy": ("gk", "indian_economy"),
        "modern-indian-history": ("gk", "indian_history"), "ancient-indian-history": ("gk", "indian_history"),
        "medieval-indian-history": ("gk", "indian_history"), "awards-static": ("gk", "awards_honours"),
        "books-and-authors-static": ("gk", "books_authors"), "world-geography": ("gk", "static_gk"),
        "oceanography": ("gk", "static_gk"), "static-gk": ("gk", "static_gk"),
        "important-indian-institutions": ("gk", "static_gk"),
        "other-edge-cases-possible-ssc-gk-gs-questions": ("gk", "static_gk"),
        "environment-and-ecology": ("gk", "environment_ecology"),
        "general-science-biology": ("science", "biology_basics"),
        "general-science-chemistry": ("science", "chemistry_basics"),
        "general-science-physics": ("science", "physics_basics"),
        "general-science": ("science", "everyday_science"), "science-in-everyday-life": ("science", "everyday_science"),
        "computer-technology-overlap": ("computer", "computer_fundamentals"),
    },
}
SUBJ_OF = {"MATH": "maths", "REAS": "reasoning"}
QUOTA = {"maths": 10**6, "reasoning": 10**6, "gk": 10**6, "science": 10**6, "computer": 10**6}  # take everything usable

SOL_CUT = re.compile(r"(Additional Information|Important Points|Hint|Mistake Points|Alternate Method|"
                     r"Alternative Method|Shortcut Trick)", re.I)


def clean_solution(sol, answer):
    s = re.sub(r"\[IMAGE:[^\]]*\]", " ", sol or "")
    s = SOL_CUT.split(s)[0]
    s = re.sub(r"\*\*|__|\\\\|\\(?=[{}])", "", s)
    s = re.sub(r"(?i)\b(key points|given|calculation|formula used|concept used|explanation)\s*:?\s*\n", r"\1: ", s)
    s = re.sub(r"(?i)\bkey points\s*:?\s*", "", s)
    # Solutions number options 1-4; the app letters them A-D.
    s = re.sub(r"([Oo]ption)\s*([“\"'‘(]?)([1-4])\b", lambda m: f"{m[1]} {m[2]}{'ABCD'[int(m[3]) - 1]}", s)
    s = s.replace("•", "")
    s = clean(s)
    s = re.sub(r"\s*\n\s*", " ", s)
    s = re.sub(r"\s{2,}", " ", s).strip()
    if len(s) > 480:
        cut = s[:480]
        end = max(cut.rfind(". "), cut.rfind("। "))
        s = cut[: end + 1] if end > 150 else cut.rstrip() + "…"
    if len(s) < 25 or LATEX.search(s):
        s = f"Correct answer: {answer}."
    return s


def ssc(root, years, seed=7):
    base = Path(root) / "subjectwise-db"
    pools, seen = {}, set()
    for exam, name in SSC_NAME.items():
        for code, chapters in CHAPTERS.items():
            f = base / exam / "pre" / code / "questions.jsonl"
            if not f.exists():
                continue
            for line in f.open(encoding="utf-8"):
                x = json.loads(line)
                if int(x["year"]) not in years or x.get("type", "mcq") != "mcq":
                    continue
                m = chapters.get(x.get("chapter"))
                if m is None:
                    continue
                subj, topic = m if isinstance(m, tuple) else (SUBJ_OF[code], m)
                q = clean(x["question"])
                opts = [clean(o["text"]) for o in x["options"]]
                labels = [o["label"] for o in x["options"]]
                if (not q or len(q) > 900 or IMAGE.search(q) or not ok_options(opts)
                        or LATEX.search(q + " " + " ".join(opts))
                        or x["correct"] not in labels or key(q, opts) in seen):
                    continue
                if subj in ("gk", "computer") and DATED.search(q + " " + " ".join(opts)):
                    continue
                seen.add(key(q, opts))
                a = labels.index(x["correct"])
                label = f"{name} {x['year']}"
                held = fmt_date(x.get("held_on") or x.get("paper_meta", {}).get("held_on"))
                if held:
                    label += f" · {held}"
                if x.get("shift"):
                    label += f" · Shift {x['shift']}"
                pools.setdefault(subj, []).append({
                    "qid": x["qid"], "exam": name, "year": int(x["year"]), "s": subj, "t": topic, "d": 2,
                    "q_en": q, "o_en": opts, "a": a, "e_en": clean_solution(x.get("solution"), opts[a]),
                    "pyq": label,
                })
    rng = random.Random(seed)
    out = []
    for subj, pool in sorted(pools.items()):
        # Newest papers first, round-robin across exams so no single exam crowds out the rest.
        by = {}
        for r in pool:
            by.setdefault((r["year"], r["exam"]), []).append(r)
        for rows in by.values():
            rng.shuffle(rows)
        # One queue per exam, newest year last (popped first).
        queues = {}
        for (year, exam), rows in sorted(by.items()):
            queues.setdefault(exam, []).extend(rows)
        queues = list(queues.values())
        picked = []
        while len(picked) < QUOTA[subj] and any(queues):
            for qu in queues:
                if qu and len(picked) < QUOTA[subj]:
                    picked.append(qu.pop())
        print(f"  ssc {subj}: {len(pool)} usable, kept {len(picked)}")
        out.extend(picked)
    # Stable ids: derived from the source question id, so re-running never reshuffles them.
    items = []
    for r in sorted(out, key=lambda r: (r["s"], r["qid"])):
        items.append({"id": f"pyq-ssc-{r['qid'][-10:]}", **{k: r[k] for k in
                      ("s", "t", "d", "q_en", "o_en", "a", "e_en", "pyq")}})
    return items


# RRB JE topic labels -> taxonomy topic (matched by keyword, first hit wins).
JE_TOPICS = {
    "maths": [("mensuration", "mensuration"), ("statics", "data_interpretation"), ("profit", "profit_loss"), ("discount", "profit_loss"), ("percent", "percentage"),
              ("ratio", "ratio_proportion"), ("average", "average"),
              ("statistic", "data_interpretation"), ("data", "data_interpretation"),
              ("algebra", "algebra"), ("speed", "time_speed_distance"), ("work", "time_work"),
              ("interest", "si_ci"), ("si and ci", "si_ci"), ("l.c.m", "hcf_lcm"), ("lcm", "hcf_lcm"),
              ("geometry", "geometry"), ("trigonometry", "trigonometry"), ("number", "number_system")],
    "reasoning": [("analogy", "analogy"), ("coding", "coding_decoding"), ("series", "series"),
                  ("seating", "puzzle_seating"), ("floor", "puzzle_seating"), ("puzzle", "puzzle_seating"),
                  ("order", "puzzle_seating"), ("rank", "puzzle_seating"), ("scheduling", "puzzle_seating"),
                  ("blood", "blood_relations"), ("direction", "direction_sense"), ("syllogism", "syllogism"),
                  ("statement", "statement_conclusion"), ("sufficiency", "statement_conclusion"),
                  ("odd one", "classification"), ("letters", "alphabet_test"), ("alphabet", "alphabet_test"),
                  ("venn", "syllogism")],
    "science": [("chemistry", "chemistry_basics"), ("physics", "physics_basics"), ("health", "human_body"),
                ("biology", "biology_basics"), ("environment", "environment_pollution"),
                ("energy", "environment_pollution"), ("technology", "inventions_discoveries"),
                ("materials", "chemistry_basics")],
}
JE_DEFAULT = {"maths": "number_system", "reasoning": "mathematical_operations", "science": "everyday_science"}


def je_topic(subj, hint):
    h = hint.lower()
    return next((t for k, t in JE_TOPICS[subj] if k in h), JE_DEFAULT[subj])


def rrb_je_bank(rows):
    """Bank items for RRB JE. The source has no explanations; until each one is
    reviewed and explained, the explanation states the official answer."""
    return [{"id": "pyq-je-" + r["sid"].removeprefix("rrbje-"), "s": r["subj"], "t": je_topic(r["subj"], r["topic_hint"]),
             "d": 2, "q_en": r["q"], "o_en": r["o"], "a": r["a"],
             "e_en": f"Correct answer: {r['o'][r['a']]} (official answer key).", "pyq": r["label"]} for r in rows]


def write_bank(name, items):
    # content/pyq/ is a separate pack from content/bank/ (see build_bundle.py): the app
    # loads it only when the PYQ section opens. One item per line keeps diffs readable
    # without the size of indented JSON.
    dest = ROOT / "content/pyq" / f"{name}.json"
    dest.parent.mkdir(exist_ok=True)
    dest.write_text("[\n" + ",\n".join(json.dumps(i, ensure_ascii=False) for i in items) + "\n]\n", encoding="utf-8")
    print(f"{name}: {len(items)} questions -> {dest.relative_to(ROOT)}")


def write_staging(name, rows):
    STAGING.mkdir(parents=True, exist_ok=True)
    with (STAGING / f"{name}.jsonl").open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"{name}: {len(rows)} questions -> {STAGING / name}.jsonl")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--rrb-je")
    ap.add_argument("--ssc")
    ap.add_argument("--ssc-years", default="2019,2020,2021,2022,2023,2024,2025,2026")
    args = ap.parse_args()
    if args.rrb_je:
        rows = rrb_je(args.rrb_je)
        write_staging("rrb_je", rows)
        write_bank("rrb_je", rrb_je_bank(rows))
    if args.ssc:
        items = ssc(args.ssc, {int(y) for y in args.ssc_years.split(",")})
        for name in sorted({i["pyq"].split(" 20")[0] for i in items}):  # one file per exam
            write_bank(name.lower().replace(" ", "_"), [i for i in items if i["pyq"].split(" 20")[0] == name])
