"""Previous-year-paper pages for the RailPariksha website (used by build_site.py).

One page per paper, subject and chunk of at most CHUNK questions: the real question in Hindi and English, the
answer, and the worked explanation, so a student searching for "RRB NTPC 10 Jun 2025 maths questions" lands on
the actual questions with solutions. Plus an index page per exam and one overall index. Every page carries real
content (questions and explanations), never an empty template.
"""
import collections
import json
import re
from pathlib import Path

CHUNK = 50
AD_AFTER = 5  # one ad unit after the first few questions, one at the end; none on index pages


def slug(text):
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", text.lower())).strip("-")


def load(content_dir):
    """{exam_file_stem: {paper_label: {subject_id: [questions]}}} in a stable order."""
    exams = {}
    for p in sorted((Path(content_dir) / "pyq").glob("*.json")):
        papers = collections.defaultdict(lambda: collections.defaultdict(list))
        for q in json.loads(p.read_text(encoding="utf-8")):
            if q.get("q_hi") and q.get("q_en") and q.get("e_hi") and q.get("e_en"):
                papers[q["pyq"]][q["s"]].append(q)
        exams[p.stem] = papers
    return exams


def add_pyq_pages(h, tax, content_dir, base, write):
    """h: dict of helpers from build_site (page, esc, question_html, crumbs_html, json_ld, breadcrumb_ld,
    faq_ld, ad_unit, ORG_NAME). Returns the HTML of a block linking the exam indexes, for the home page."""
    page, esc, qhtml = h["page"], h["esc"], h["question_html"]
    crumbs_html, json_ld, breadcrumb_ld, ad_unit = h["crumbs_html"], h["json_ld"], h["breadcrumb_ld"], h["ad_unit"]
    org = h["ORG_NAME"]
    subj = {s["id"]: s for s in tax["subjects"]}
    exam_names = {e["id"]: e for e in tax["exams"]}
    exams = load(content_dir)
    index_links = []
    for stem, papers in exams.items():
        e = exam_names.get(stem)
        ename_hi = e["hi"] if e else stem
        ename_en = e["en"] if e else stem
        rows = []
        for label in sorted(papers):
            by_subj = papers[label]
            total = sum(len(v) for v in by_subj.values())
            parts = []
            first_pages = {sid: f"pyq-{slug(label)}-{sid}-1.html" for sid in by_subj}
            for sid in sorted(by_subj):
                qs = by_subj[sid]
                s = subj.get(sid, {"hi": sid, "en": sid})
                pages = [qs[i:i + CHUNK] for i in range(0, len(qs), CHUNK)]
                for n, chunk in enumerate(pages, 1):
                    name = f"pyq-{slug(label)}-{sid}-{n}.html"
                    url = f"{base}/{name}"
                    part = f" (भाग {n})" if len(pages) > 1 else ""
                    idx = f"pyq-{stem}.html"
                    crumbs = crumbs_html([("Home", "index.html"), (ename_hi, idx), (label, None)])
                    first = (n - 1) * CHUNK + 1
                    body_qs = []
                    for i, q in enumerate(chunk):
                        body_qs.append(qhtml(q, first + i))
                        if i + 1 == AD_AFTER and len(chunk) > AD_AFTER + 3:
                            body_qs.append(ad_unit())
                    body_qs.append(ad_unit())
                    prev_a = (f"<a href='pyq-{slug(label)}-{sid}-{n - 1}.html'>← पिछला भाग</a>" if n > 1 else "<span></span>")
                    next_a = (f"<a href='pyq-{slug(label)}-{sid}-{n + 1}.html'>अगला भाग →</a>" if n < len(pages) else "<span></span>")
                    body_qs.append(f"<div class='pager'>{prev_a}{next_a}</div>")
                    others = "".join(f"<a href='{nm}'>{esc(subj.get(o, {'hi': o})['hi'])}</a>"
                                     for o, nm in first_pages.items() if o != sid)
                    if others:
                        body_qs.append(f"<h2>इसी पेपर के अन्य विषय</h2><div class='chips'>{others}</div>")
                    intro = (f"<div class='answer'>{esc(label)} — {esc(s['hi'])} ({esc(s['en'])}) के "
                             f"{len(chunk)} प्रश्न{part}, सही उत्तर और हिंदी-अंग्रेज़ी स्पष्टीकरण सहित। "
                             f"These are the {s['en']} questions from {esc(label)} with answers and bilingual "
                             f"explanations.</div>")
                    structured = json_ld(breadcrumb_ld(base, [("Home", "index.html"), (ename_hi, idx), (label, None)]))
                    body = (crumbs + f"<h1>{esc(label)} — {esc(s['hi'])}{part}</h1>"
                            f"<p class='muted'>{esc(ename_en)} previous year paper · {esc(s['en'])}</p>" + intro
                            + "".join(body_qs))
                    write(name, page(f"{label} {s['hi']} प्रश्न उत्तर सहित{part} | {ename_en} PYQ | {org}",
                                     f"{label}: {s['hi']} ({s['en']}) के {len(chunk)} प्रश्न, सही उत्तर व स्पष्टीकरण।",
                                     body, url, base, structured), priority=0.6, changefreq="yearly")
                    parts.append(f"<a href='{name}'>{esc(s['hi'])}{part} ({len(chunk)})</a>")
            rows.append(f"<div class='card'><strong>{esc(label)}</strong> <span class='muted'>· {total} प्रश्न</span>"
                        f"<p class='links'>{' · '.join(parts)}</p></div>")
        idx = f"pyq-{stem}.html"
        body = (crumbs_html([("Home", "index.html"), (ename_hi, None)]) +
                f"<h1>{esc(ename_hi)} — पिछले साल के प्रश्न पत्र</h1>"
                f"<p class='muted'>{esc(ename_en)} previous year papers, {len(papers)} shifts/papers</p>" + "".join(rows))
        write(idx, page(f"{ename_hi} ({ename_en}) पिछले साल के प्रश्न पत्र उत्तर सहित | {org}",
                        f"{ename_en} के सभी पिछले साल के प्रश्न पत्र: तारीख व शिफ्ट के अनुसार, सही उत्तर और स्पष्टीकरण सहित।",
                        body, f"{base}/{idx}", base, json_ld(breadcrumb_ld(base, [("Home", "index.html"), (ename_hi, None)]))),
              priority=0.8, changefreq="monthly")
        index_links.append(f"<a class='card' href='{idx}'><strong>{esc(ename_hi)}</strong><br>"
                           f"<span class='muted'>{len(papers)} papers · PYQ</span></a>")
    return "".join(index_links)
