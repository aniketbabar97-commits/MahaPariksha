"""Extract questions + official answers from RRB/RPF candidate response-sheet PDFs.

Response sheets are the papers RRB publishes during the answer-key window: every
question with its four options, the correct one marked green with a tick icon.
This reads them from the PDF's text layer -- no OCR -- so a sheet whose questions
are images (most pre-2022 sheets) yields nothing and is reported as such.

The correct option is taken from, in order: the option label/text colour (green),
else the tick icon's position (it sits a few points right of the cross icons).
A question is dropped when any of these hold: no single correct option can be
identified, it doesn't have exactly 4 non-empty options, or a figure sits inside
its stem (the text alone can't be answered).

  python3 pipeline/pyq/response_sheets.py PDF... [--json OUT]
"""
import argparse
import json
import re
import sys
from pathlib import Path

import fitz  # PyMuPDF

VERSION = 3  # bump when extraction output changes (invalidates build_rrb's cache)
GREEN, RED = 0x40C64B, 0xF61818
DEVANAGARI = re.compile(r"[ऀ-ॿ]")
OPT_LABEL = re.compile(r"^\s*([A-D]|[1-4])\.\s*$|^\s*([A-D]|[1-4])\.\s")
NOISE = re.compile(r"^(Question ID|Option \d ID|Status|Chosen Option|Participant|Test Center|Roll No|"
                   r"Participants Name|Test Center Name|\* Note|Correct Answer will|Incorrect Answer will|"
                   r"\d\. Options shown|\d\. Chosen option|Note|Answered|Not Answered|Marked For Review)", re.I)


SUP = str.maketrans("0123456789+-−=()nixyz", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻⁻⁼⁽⁾ⁿⁱˣʸᶻ")


def superscript(t):
    """Render a superscript span: Unicode superscripts when every character has one
    ("2" -> "²"), else caret notation ("0.27" -> "^0.27") so 87^0.27 doesn't read as 870.27."""
    core = t.strip()
    if core and all(c in "0123456789+-−=()nixyz" for c in core):
        return t.replace(core, core.translate(SUP))
    return t.replace(core, "^" + (core if " " not in core else f"({core})")) if core else t


def lines_of(page):
    """Visual lines as dicts (y, x, text, colors), in reading order.

    - White spans are dropped: the sheets plant invisible white numbers as an
      anti-copy trap, and they would otherwise land inside question text.
    - Whitespace-only spans are kept (Hindi sheets encode word spaces as their own
      spans); Devanagari glyph fragments that touch are joined without a space.
    - Lines are grouped into rows with a small y tolerance before sorting by x, so a
      stem's first line that sits 0.5pt above its "Q.n" label isn't read first.
    """
    raw = []
    for b in page.get_text("dict")["blocks"]:
        for ln in b.get("lines", []):
            full = "".join(s["text"] for s in ln["spans"]).strip()
            # (Section headers are white text on a dark bar -- keep those.)
            spans = [s for s in ln["spans"] if s["text"] and (s["color"] != 0xFFFFFF or full.startswith("Section"))]
            if not "".join(s["text"] for s in spans).strip():
                continue
            text, prev = "", None
            for s in spans:
                t = s["text"]
                if s["flags"] & 1 and prev is not None:  # PyMuPDF marks superscript spans
                    t = superscript(t)
                if prev is not None:
                    gap = s["bbox"][0] - prev["bbox"][2]
                    if gap > 1.2 and not text.endswith(" ") and not t.startswith(" "):
                        text += " "
                text += t
                prev = s
            vis = [s for s in spans if s["text"].strip()]
            raw.append({"y": ln["bbox"][1], "x": round(vis[0]["bbox"][0], 1), "text": re.sub(r"\s+", " ", text).strip(),
                        "colors": {s["color"] for s in vis}})
    raw.sort(key=lambda l: l["y"])
    rows, out = [], []
    for l in raw:
        if rows and l["y"] - rows[-1][0]["y"] <= 3:
            rows[-1].append(l)
        else:
            rows.append([l])
    for r in rows:
        out.extend(sorted(r, key=lambda l: l["x"]))
    return out


def meta(doc):
    first = "\n".join(doc[i].get_text() for i in range(min(2, len(doc))))
    def grab(label):
        m = re.search(label + r"\s*:?\s*\n?\s*([^\n]+)", first)
        return m.group(1).strip() if m else ""
    return {"date": grab("Test Date"), "time": grab("Test Time"), "subject": grab("Subject")}


MATRA = "\u0901-\u0903\u093A-\u094F\u0955-\u0957\u0962\u0963"
# A new line that starts a list item / statement keeps its line break; any other
# wrapped line is joined back into the sentence it was cut from.
KEEP_BREAK = re.compile(r"^((?:[IVX]{1,4}|\d{1,2}|[a-dA-D])[.)]\s|\(?[ivx]{1,4}\)\s|(Statements?|Conclusions?|Assumptions?|"
                        r"Arguments?|Courses? of action|कथन|निष्कर्ष|मान्यता|तर्क)\b)")


def fix_hindi(s):
    # The sheets' Type3 Hindi fonts emit some vowel signs twice ("हाइड्रोोकार्बन").
    return re.sub(f"([{MATRA}])\\1+", r"\1", s)


def join_lines(lines):
    out = ""
    for ln in (l.strip() for l in lines):
        if not ln:
            continue
        if not out:
            out = ln
        elif KEEP_BREAK.match(ln):
            out += "\n" + ln
        elif re.match(f"[{MATRA}]", ln):  # a word split mid-glyph ("दक्षि" / "ण")
            out += ln
        else:
            out += " " + ln
    return fix_hindi(re.sub(r"[ \t]+", " ", out)).strip()


def norm_ws(s):
    return join_lines([s])


def extract(path):
    doc = fitz.open(path)
    info = meta(doc)
    questions, cur, section = [], None, ""
    stats = {"pages": len(doc), "q_seen": 0, "dropped": {}}

    def drop(why):
        stats["dropped"][why] = stats["dropped"].get(why, 0) + 1

    def finish():
        nonlocal cur
        if not cur:
            return
        q = cur
        cur = None
        opts = q["opts"]
        if q["figure"]:
            return drop("figure")
        if len(opts) != 4 or any(not o["text"].strip() for o in opts):
            return drop("options")
        # Image options leave only a placeholder ("A", "Option 1") in the text layer.
        if all(re.fullmatch(r"(Option\s*)?[A-D1-4]", o["text"].strip(), re.I) for o in opts):
            return drop("image_options")
        if len({o["text"].strip() for o in opts}) != 4:
            return drop("dup_options")
        greens = [i for i, o in enumerate(opts) if GREEN in o["colors"]]
        if len(greens) != 1:
            # Tick icon sits further right than the cross icons.
            xs = [o.get("icon_x") for o in opts]
            if None not in xs and len(set(xs)) == 2:
                odd = [i for i, x in enumerate(xs) if xs.count(x) == 1]
                greens = odd if len(odd) == 1 and xs[odd[0]] > min(xs) else []
            else:
                greens = []
        if len(greens) != 1:
            return drop("no_answer")
        stem = join_lines(q["stem"])
        if not stem:
            return drop("empty_stem")
        questions.append({"n": q["n"], "section": q["section"], "q": stem,
                          "o": [norm_ws(o["text"]) for o in opts], "a": greens[0]})

    for pno, page in enumerate(doc):
        icons = [(i["bbox"][0], i["bbox"][1], i["bbox"][3]) for i in page.get_image_info()]
        lines = lines_of(page)
        for ln in lines:
            t = ln["text"]
            m = re.match(r"^Q\.(\d+)\b\s*(.*)$", t)
            if m:
                finish()
                stats["q_seen"] += 1
                cur = {"n": int(m.group(1)), "section": section, "stem": [m.group(2)] if m.group(2) else [],
                       "opts": [], "in_opts": False, "page": pno, "y0": ln["y"], "figure": False,
                       "label_x": ln["x"], "stem_x": None}
                continue
            sm = re.match(r"^Section\s*:[\s\xa0]*(.+)$", t)
            if sm:
                finish()
                section = sm.group(1).strip()
                continue
            if cur is None or NOISE.match(t) or re.match(r"^(Test Date|Test Time|Subject)\b", t):
                continue
            if t == "Ans" or t.startswith("Ans "):
                cur["in_opts"] = True
                cur["ans_y"] = (pno, ln["y"])
                rest = t[3:].strip()
                if not rest:
                    continue
                t = rest
            if cur["in_opts"]:
                lm = OPT_LABEL.match(t)
                if lm and len(cur["opts"]) < 4:
                    icon = [x for x, y0, y1 in icons if y0 - 4 <= ln["y"] <= y1 + 4 and x < ln["x"]]
                    cur["opts"].append({"text": t[lm.end():].strip() if lm.group(2) else "",
                                        "colors": set(ln["colors"]), "icon_x": round(max(icon)) if icon else None})
                elif cur["opts"]:
                    o = cur["opts"][-1]
                    o["text"] = join_lines([o["text"], t])
                    o["colors"] |= ln["colors"]
            else:
                # A long question number wraps in the narrow label column ("Q.8" / "3" = Q.83):
                # a lone number left of where the stem text starts belongs to the label.
                if (re.fullmatch(r"\d{1,3}", t) and not cur["stem"][1:] and
                        (cur["stem_x"] is None or ln["x"] < cur["stem_x"] - 3) and ln["x"] < cur["label_x"] + 12):
                    cur["n"] = int(f"{cur['n']}{t}")
                    continue
                if cur["stem_x"] is None:
                    cur["stem_x"] = ln["x"]
                cur["stem"].append(t)
        # A figure inside a stem: an image between the question's first line and its "Ans" line.
        if cur and not cur["in_opts"]:
            pass
        for q_img in icons:
            x, y0, y1 = q_img
            if x > 50 and cur and not cur["in_opts"] and cur["page"] == pno and y0 > cur["y0"]:
                cur["figure"] = True
    finish()
    # Figures inside stems on earlier questions: re-scan per page by position.
    stats["kept"] = len(questions)
    return info, questions, stats


def figure_scan(path, questions):
    """Mark questions whose stem region contains an image (figure-based questions)."""
    doc = fitz.open(path)
    flagged = set()
    for page in doc:
        lines = lines_of(page)
        imgs = [(i["bbox"][0], i["bbox"][1]) for i in page.get_image_info()]
        qs = [(l["y"], int(re.match(r"^Q\.(\d+)", l["text"]).group(1))) for l in lines if re.match(r"^Q\.\d+", l["text"])]
        ans = [l["y"] for l in lines if l["text"].startswith("Ans")]
        for qy, n in qs:
            ay = min([a for a in ans if a >= qy], default=None)
            if ay is None:
                continue
            if any(qy - 2 <= y <= ay - 2 and x > 50 for x, y in imgs):
                flagged.add(n)
    return [q for q in questions if q["n"] not in flagged], len(flagged)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("pdfs", nargs="+")
    ap.add_argument("--json")
    a = ap.parse_args()
    out = []
    for p in a.pdfs:
        try:
            info, qs, st = extract(p)
            qs, nfig = figure_scan(p, qs)
            st["kept"], st["figures"] = len(qs), nfig
        except Exception as e:  # a corrupt PDF must not stop a batch
            print(f"{p}: ERROR {e}", file=sys.stderr)
            continue
        print(f"{Path(p).name}: {info} {st}")
        out.append({"file": str(p), **info, "stats": st, "questions": qs})
    if a.json:
        Path(a.json).write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
