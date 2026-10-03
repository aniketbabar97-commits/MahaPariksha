"""Static SEO/AEO site from the question bank: exam pages, subject pages, topic practice
pages, privacy policy, sitemap, robots.txt and schema.org structured data.

Usage: python pipeline/build_site.py --out site [--base-url https://example.github.io/repo]

Every factual claim placed on a page or inside a JSON-LD block (subject weightage,
negative marking, question counts, syllabus) is read directly from content/taxonomy.json
or the content/bank/*.json question packs -- nothing here is invented or estimated.
"""
import argparse
import html
import json
import os
import shutil
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
PLAY_URL = "https://play.google.com/store/apps/details?id=app.railpariksha"
SUPPORT_EMAIL = os.environ.get("SUPPORT_EMAIL", "support@railpariksha.app")
LETTERS = ["अ", "ब", "क", "ड"]
ORG_NAME = "RailPariksha"
# No production domain is live yet (see docs/LAUNCH.md); this placeholder keeps
# canonical/OG/JSON-LD URLs absolute (required by the sitemap protocol and by
# schema.org) instead of emitting protocol-relative "/page.html" URLs. Pass
# --base-url or set SITE_URL once the real domain is bought to override it.
DEFAULT_BASE_URL = "https://railpariksha.app"

# Known negative-marking fractions, spelled out for direct-answer / FAQ text.
# Sourced from taxonomy.json's "neg" field on each exam (RRB = 1/3, RPF/PSU = 1/4).
NEG_FRACTIONS = {0.3333: "1/3", 0.25: "1/4", 0: None}

CSS = """
:root{--navy:#0B3D91;--navy2:#154BAF;--gold:#F5B400;--sun:#FFD066;--bg:#F5F7FC;--card:#fff;--text:#16203a;--muted:#5b6479;--ok:#1E9E5A}
@media (prefers-color-scheme:dark){:root{--bg:#0E1320;--card:#1A2133;--text:#e8ecf5;--muted:#9aa3b8}}
*{box-sizing:border-box}body{margin:0;font-family:"Noto Sans Devanagari","Mukta",system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.6}
a{color:var(--navy2)}header{background:linear-gradient(135deg,var(--navy),var(--navy2));color:#fff;padding:28px 16px}
header a{color:#fff;text-decoration:none}.wrap{max-width:860px;margin:0 auto;padding:0 16px}
h1{margin:.2em 0;font-size:1.8rem}.tag{color:var(--sun);font-weight:700}
.cta{display:inline-block;background:var(--gold);color:#16203a!important;font-weight:800;padding:12px 20px;border-radius:14px;text-decoration:none;margin-top:10px}
.card{background:var(--card);border-radius:18px;padding:16px 18px;margin:14px 0;box-shadow:0 2px 10px rgba(0,0,0,.05)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}
.q{font-weight:700}.opts{margin:.4em 0 .6em;padding-left:0;list-style:none}.opts li{padding:2px 0}
details summary{cursor:pointer;color:var(--navy2);font-weight:700}.ans{color:var(--ok);font-weight:800}
.muted{color:var(--muted);font-size:.9rem}footer{padding:30px 16px;color:var(--muted);font-size:.9rem}
.answer{background:var(--card);border-left:4px solid var(--gold);border-radius:8px;padding:12px 16px;margin:12px 0 18px;font-size:1.02rem}
.crumbs{font-size:.85rem;color:var(--muted);margin-bottom:6px}.crumbs a{color:var(--muted)}
.links{margin:.3em 0}.faq dt{font-weight:700;margin-top:10px}.faq dd{margin:.2em 0 0}
"""


def esc(s):
    return html.escape(str(s), quote=True)


def json_ld(*blocks):
    """Render one or more structured-data objects as separate <script> blocks."""
    out = []
    for b in blocks:
        if not b:
            continue
        out.append('<script type="application/ld+json">' +
                    json.dumps(b, ensure_ascii=False, separators=(",", ":")) + "</script>")
    return "".join(out)


def breadcrumb_ld(base, items):
    """items: list of (name, url-or-None-for-current)."""
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {"@type": "ListItem", "position": i + 1, "name": name,
             **({"item": f"{base}/{url}"} if url else {})}
            for i, (name, url) in enumerate(items)
        ],
    }


def faq_ld(pairs):
    """pairs: list of (question, answer plain text). Returns None if empty."""
    if not pairs:
        return None
    return {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {"@type": "Question", "name": q,
             "acceptedAnswer": {"@type": "Answer", "text": a}}
            for q, a in pairs
        ],
    }


def crumbs_html(items):
    parts = []
    for name, url in items:
        parts.append(f"<a href='{url}'>{esc(name)}</a>" if url else f"<span>{esc(name)}</span>")
    return f"<nav class='crumbs'>{' › '.join(parts)}</nav>"


def neg_fraction(neg):
    for k, v in NEG_FRACTIONS.items():
        if abs(neg - k) < 1e-4:
            return v
    return f"{neg:g}"


def neg_text_hi(neg):
    if not neg:
        return "कोई नकारात्मक अंकन नहीं"
    frac = neg_fraction(neg)
    return f"प्रत्येक गलत उत्तर पर {frac or f'{neg:g}'} अंक की कटौती"


def neg_text_en(neg):
    if not neg:
        return "no negative marking"
    frac = neg_fraction(neg)
    return f"{frac or f'{neg:g}'} mark deducted for every wrong answer"


def page(title, desc, body, canonical, base, structured="", og_type="website"):
    return f"""<!doctype html><html lang="hi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{esc(title)}</title><meta name="description" content="{esc(desc)}">
<link rel="canonical" href="{canonical}">
<link rel="icon" href="favicon-32.png" sizes="32x32">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta property="og:type" content="{og_type}"><meta property="og:site_name" content="{ORG_NAME}">
<meta property="og:title" content="{esc(title)}"><meta property="og:description" content="{esc(desc)}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{base}/og-image.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{esc(title)}"><meta name="twitter:description" content="{esc(desc)}">
<meta name="twitter:image" content="{base}/og-image.png">
<style>{CSS}</style>{structured}</head><body>
<header><div class="wrap"><a href="index.html"><strong>RailPariksha · रेलपरीक्षा</strong></a>
<div class="tag">Train to succeed · सफलता की पटरी पर</div></div></header>
<main class="wrap">{body}
<div class="card"><strong>रोज़ मुफ़्त अभ्यास करें!</strong><br>Daily 10, फ्लैशकार्ड, मॉक टेस्ट, स्ट्रीक और भी बहुत कुछ।<br>
<a class="cta" href="{PLAY_URL}">Google Play से डाउनलोड करें</a></div></main>
<footer class="wrap">RailPariksha एक स्वतंत्र शैक्षणिक ऐप है; भारतीय रेलवे, RRB या RPF से संबद्ध नहीं है। ·
<a href="privacy.html">Privacy Policy</a> · {SUPPORT_EMAIL}</footer></body></html>"""


def question_html(q, n):
    opts = "".join(f"<li>({LETTERS[i]}) {esc(o)}</li>" for i, o in enumerate(q["o_hi"]))
    extra = ""
    if q.get("hook_hi"):
        extra += f"<p>💡 {esc(q['hook_hi'])}</p>"
    return f"""<div class="card"><div class="q">{n}. {esc(q['q_hi'])}</div>
<div class="muted">{esc(q['q_en'])}</div><ul class="opts">{opts}</ul>
<details><summary>उत्तर व स्पष्टीकरण देखें</summary>
<p class="ans">उत्तर: ({LETTERS[q['a']]}) {esc(q['o_hi'][q['a']])}</p>
<p>{esc(q['e_hi'])}</p>{extra}<p class="muted">{esc(q['e_en'])}</p></details></div>"""


def question_answer_plain(q):
    """Plain-text answer for a question, used only inside Quiz JSON-LD (no HTML)."""
    return f"{q['o_en'][q['a']]} ({q['o_hi'][q['a']]}). {q['e_en']}"


MAX_QUIZ_LD_ITEMS = 10  # cap JSON-LD payload size; full list stays visible in the HTML body


def quiz_ld(name, url, items):
    if not items:
        return None
    sample = items[:MAX_QUIZ_LD_ITEMS]
    return {
        "@context": "https://schema.org",
        "@type": "Quiz",
        "name": name,
        "url": url,
        "educationalLevel": "Competitive exam",
        "about": {"@type": "Thing", "name": name},
        "hasPart": [
            {"@type": "Question", "name": q["q_en"],
             "acceptedAnswer": {"@type": "Answer", "text": question_answer_plain(q)}}
            for q in sample
        ],
    }


def course_ld(e, url, subjects, base):
    about = [{"@type": "Thing", "name": subjects[s["id"]]["en"]}
              for s in e["subjects"] if s["id"] in subjects]
    weightage = [
        {"@type": "PropertyValue", "name": f"{subjects[s['id']]['en']} weightage",
         "value": f"{s['w']}%"}
        for s in e["subjects"] if s["id"] in subjects
    ]
    if e.get("neg"):
        weightage.append({"@type": "PropertyValue", "name": "Negative marking",
                           "value": neg_text_en(e["neg"])})
    return {
        "@context": "https://schema.org",
        "@type": "Course",
        "name": e["en"],
        "alternateName": e["hi"],
        "description": f"Subject-wise practice questions and mock tests for {e['en']} with answers and explanations.",
        "url": url,
        "provider": {"@type": "Organization", "name": ORG_NAME, "url": f"{base}/index.html"},
        "about": about,
        "isAccessibleForFree": True,
        "additionalProperty": weightage,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="site")
    ap.add_argument("--base-url", default=os.environ.get("SITE_URL", ""))
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    base = (a.base_url or DEFAULT_BASE_URL).rstrip("/")
    if not a.base_url:
        print(f"note: --base-url/SITE_URL not set, using placeholder domain {base} "
              f"for canonical/sitemap/JSON-LD URLs")
    tax = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    qs = []
    for p in sorted((CONTENT / "bank").glob("*.json")):
        qs.extend(json.loads(p.read_text(encoding="utf-8")))
    subjects = {s["id"]: s for s in tax["subjects"]}
    url_meta = []  # (path, priority, changefreq)

    def write(name, content, priority=0.5, changefreq="monthly"):
        (out / name).write_text(content, encoding="utf-8")
        url_meta.append((name, priority, changefreq))

    # ---- Topic pages -------------------------------------------------
    topic_counts = {}
    topic_pages = {}  # (sid,tid) -> filename
    for s in tax["subjects"]:
        for t in s["topics"]:
            items = [q for q in qs if q["s"] == s["id"] and q["t"] == t["id"]]
            if not items:
                continue
            topic_counts[(s["id"], t["id"])] = len(items)
            name = f"{s['id']}-{t['id']}.html"
            topic_pages[(s["id"], t["id"])] = name

    for s in tax["subjects"]:
        for t in s["topics"]:
            key = (s["id"], t["id"])
            if key not in topic_counts:
                continue
            n = topic_counts[key]
            items = [q for q in qs if q["s"] == s["id"] and q["t"] == t["id"]]
            name = topic_pages[key]
            url = f"{base}/{name}"
            subj_page = f"subject-{s['id']}.html"
            crumbs = crumbs_html([("Home", "index.html"), (s["hi"], subj_page), (t["hi"], None)])
            answer_para = (
                f"<div class='answer'><strong>{esc(t['hi'])} ({esc(t['en'])})</strong> "
                f"{n} अभ्यास प्रश्नों का अभ्यास कराता है, प्रत्येक का सही उत्तर व हिंदी-अंग्रेज़ी में सरल "
                f"स्पष्टीकरण सहित। यह {esc(s['hi'])} ({esc(s['en'])}) विषय का हिस्सा है। There are {n} practice "
                f"MCQs for {esc(t['en'])} here, each with the correct answer and a bilingual explanation.</div>"
            )
            related = f"<p class='links muted'>विषय: <a href='{subj_page}'>{esc(s['hi'])} · {esc(s['en'])}</a></p>"
            faq_pairs = [
                (f"How many practice questions are available for {t['en']}?",
                 f"RailPariksha currently has {n} {t['en']} practice questions with answers and explanations, "
                 f"part of the {s['en']} subject."),
                (f"{t['hi']} के कितने अभ्यास प्रश्न उपलब्ध हैं?",
                 f"RailPariksha पर {t['hi']} के {n} अभ्यास प्रश्न उपलब्ध हैं, सही उत्तर व स्पष्टीकरण सहित।"),
            ]
            structured = json_ld(
                breadcrumb_ld(base, [("Home", "index.html"), (s["hi"], subj_page), (t["hi"], None)]),
                quiz_ld(f"{t['en']} — {s['en']} Quiz", url, items),
                faq_ld(faq_pairs),
            )
            body = (crumbs + f"<h1>{esc(t['hi'])} — {esc(s['hi'])} अभ्यास प्रश्न</h1>"
                    f"<p class='muted'>{esc(t['en'])} · {esc(s['en'])} MCQ with answers & explanation · "
                    f"{n} प्रश्न</p>" + answer_para + related +
                    "".join(question_html(q, i + 1) for i, q in enumerate(items)))
            write(name, page(f"{t['hi']} ({t['en']}) अभ्यास प्रश्न उत्तर सहित | {s['hi']} MCQ | {ORG_NAME}",
                             f"{t['hi']} पर {n} अभ्यास प्रश्न, सही उत्तर व सरल स्पष्टीकरण। {s['en']} {t['en']} MCQ in Hindi.",
                             body, url, base, structured), priority=0.5, changefreq="monthly")

    # ---- Subject pages -------------------------------------------------
    exams_by_subject = {}
    for e in tax["exams"]:
        for entry in e["subjects"]:
            exams_by_subject.setdefault(entry["id"], []).append((e, entry["w"]))

    for s in tax["subjects"]:
        topic_links = [f"<a href='{topic_pages[(s['id'], t['id'])]}'>{esc(t['hi'])}</a> ({topic_counts[(s['id'], t['id'])]})"
                       for t in s["topics"] if (s["id"], t["id"]) in topic_pages]
        if not topic_links:
            continue
        exam_links = [f"<a href='exam-{e['id']}.html'>{esc(e['hi'])}</a> ({w}%)"
                      for e, w in exams_by_subject.get(s["id"], [])]
        name = f"subject-{s['id']}.html"
        total_qs = sum(topic_counts[(s["id"], t["id"])] for t in s["topics"] if (s["id"], t["id"]) in topic_counts)
        url = f"{base}/{name}"
        crumbs = crumbs_html([("Home", "index.html"), (s["hi"], None)])
        answer_para = (
            f"<div class='answer'>{esc(s['hi'])} ({esc(s['en'])}) में {len(topic_links)} टॉपिक और कुल "
            f"{total_qs} अभ्यास प्रश्न हैं। यह विषय " +
            (", ".join(esc(e['hi']) for e, _ in exams_by_subject.get(s['id'], [])) or "कई परीक्षाओं") +
            f" में पूछा जाता है। {esc(s['en'])} covers {len(topic_links)} topics with {total_qs} practice "
            f"questions on RailPariksha, and appears in " +
            (", ".join(esc(e['en']) for e, _ in exams_by_subject.get(s['id'], [])) or "several exams") +
            ".</div>"
        )
        structured = json_ld(
            breadcrumb_ld(base, [("Home", "index.html"), (s["hi"], None)]),
            {
                "@context": "https://schema.org", "@type": "ItemList", "name": f"{s['en']} topics",
                "itemListElement": [
                    {"@type": "ListItem", "position": i + 1, "name": t["en"],
                     "url": f"{base}/{topic_pages[(s['id'], t['id'])]}"}
                    for i, t in enumerate(s["topics"]) if (s["id"], t["id"]) in topic_pages
                ],
            },
        )
        body = (crumbs + f"<h1>{esc(s['hi'])} ({esc(s['en'])}) अभ्यास प्रश्न</h1>" + answer_para +
                f"<h2>टॉपिक चुनें · Topics</h2><p class='links'>{' · '.join(topic_links)}</p>" +
                (f"<h2>यह विषय इन परीक्षाओं में आता है · Appears in these exams</h2>"
                 f"<p class='links'>{' · '.join(exam_links)}</p>" if exam_links else ""))
        write(name, page(f"{s['hi']} ({s['en']}) अभ्यास प्रश्न — सभी टॉपिक | {ORG_NAME}",
                         f"{s['hi']} ({s['en']}) के {len(topic_links)} टॉपिक और {total_qs} अभ्यास प्रश्न, उत्तर व स्पष्टीकरण सहित।",
                         body, url, base, structured), priority=0.7, changefreq="weekly")

    # ---- Exam pages ------------------------------------------------
    exam_cards = []
    for e in tax["exams"]:
        subj_links = []
        for entry in e["subjects"]:
            sid, w = entry["id"], entry["w"]
            s = subjects.get(sid)
            if not s:
                continue
            tl = [f"<a href='{topic_pages[(sid, t['id'])]}'>{esc(t['hi'])}</a> ({topic_counts[(sid, t['id'])]})"
                  for t in s["topics"] if (sid, t["id"]) in topic_counts]
            if tl:
                subj_links.append(
                    f"<div class='card'><a href='subject-{sid}.html'><strong>{esc(s['hi'])} · {esc(s['en'])} ({w}%)</strong></a><br>{' · '.join(tl)}</div>")
        if not subj_links:
            continue
        name = f"exam-{e['id']}.html"
        neg = e.get("neg", 0)
        negtxt, neg_en = neg_text_hi(neg), neg_text_en(neg)
        url = f"{base}/{name}"
        weight_bits_hi = ", ".join(f"{subjects[entry['id']]['hi']} {entry['w']}%"
                                     for entry in e["subjects"] if entry["id"] in subjects)
        weight_bits_en = ", ".join(f"{subjects[entry['id']]['en']} {entry['w']}%"
                                     for entry in e["subjects"] if entry["id"] in subjects)
        answer_para = (
            f"<div class='answer'><strong>{esc(e['hi'])} ({esc(e['en'])})</strong> में विषयवार भारांश (weightage) "
            f"इस प्रकार है — {esc(weight_bits_hi)} — और नकारात्मक अंकन: {negtxt}। {esc(e['en'])} covers "
            f"{esc(weight_bits_en)}, with {neg_en}.</div>"
        )
        crumbs = crumbs_html([("Home", "index.html"), (e["hi"], None)])
        faq_pairs = [
            (f"What is the syllabus / subject weightage for {e['en']}?",
             f"{e['en']} syllabus weightage: {weight_bits_en}."),
            (f"{e['hi']} का सिलेबस व भारांश क्या है?",
             f"{e['hi']} में विषयवार भारांश: {weight_bits_hi}।"),
            (f"What is the negative marking in {e['en']}?",
             f"{e['en']} has {neg_en}." if neg else f"{e['en']} has no negative marking."),
            (f"{e['hi']} में नकारात्मक अंकन क्या है?",
             f"{e['hi']} में {negtxt} है।"),
        ]
        structured = json_ld(
            breadcrumb_ld(base, [("Home", "index.html"), (e["hi"], None)]),
            course_ld(e, url, subjects, base),
            faq_ld(faq_pairs),
        )
        body = (crumbs + f"<h1>{esc(e['hi'])} अभ्यास प्रश्न {date.today().year}</h1>" + answer_para +
                f"<h2>विषयवार अभ्यास · Practice by subject</h2>" + "".join(subj_links))
        write(name, page(f"{e['hi']} अभ्यास प्रश्न {date.today().year} | {e['en']} MCQ Hindi | {ORG_NAME}",
                         f"{e['hi']} ({e['en']}) के लिए विषयवार अभ्यास प्रश्न, उत्तर व स्पष्टीकरण। {ORG_NAME} ऐप पर मुफ़्त मॉक टेस्ट।",
                         body, url, base, structured), priority=0.9, changefreq="weekly")
        exam_cards.append(f"<a class='card' href='{name}'><strong>{esc(e['hi'])}</strong><br><span class='muted'>{esc(e['en'])}</span></a>")

    # ---- Home ------------------------------------------------------
    subject_cards = [f"<a class='card' href='subject-{s['id']}.html'><strong>{esc(s['hi'])}</strong><br><span class='muted'>{esc(s['en'])}</span></a>"
                     for s in tax["subjects"] if any((s["id"], t["id"]) in topic_pages for t in s["topics"])]
    home_url = f"{base}/index.html"
    answer_para = (
        "<div class='answer'>RailPariksha, भारतीय रेलवे (RRB) व RPF भर्ती परीक्षाओं — जैसे RRB NTPC, ग्रुप डी, "
        "ALP, JE, पैरामेडिकल, RPF कांस्टेबल व सब-इंस्पेक्टर — के लिए विषयवार व टॉपिकवार अभ्यास प्रश्न, सही उत्तर और "
        "सरल हिंदी-अंग्रेज़ी स्पष्टीकरण मुफ़्त में उपलब्ध कराता है। RailPariksha offers free, subject-wise and "
        "topic-wise practice MCQs with answers and bilingual explanations for every major RRB and RPF exam.</div>"
    )
    structured = json_ld(
        {"@context": "https://schema.org", "@type": "Organization", "name": ORG_NAME,
         "url": home_url, "logo": f"{base}/og-image.png"},
        {"@context": "https://schema.org", "@type": "WebSite", "name": ORG_NAME, "url": home_url},
    )
    body = (crumbs_html([("Home", None)]) + "<h1>रेलवे व RPF परीक्षाओं के लिए मुफ़्त अभ्यास</h1>" + answer_para +
            f"<a class='cta' href='{PLAY_URL}'>ऐप डाउनलोड करें</a><h2>परीक्षा चुनें · Choose your exam</h2><div class='grid'>{''.join(exam_cards)}</div>"
            f"<h2>विषय के अनुसार अभ्यास करें · Practice by subject</h2><div class='grid'>{''.join(subject_cards)}</div>")
    write("index.html", page(f"{ORG_NAME} — RRB NTPC, ग्रुप डी, RPF अभ्यास प्रश्न हिंदी में",
                             "RRB NTPC, Group D, ALP, JE, RPF Constable & SI practice questions in Hindi with answers & explanations. Free daily quiz, flashcards and mock tests.",
                             body, home_url, base, structured), priority=1.0, changefreq="weekly")

    privacy_url = f"{base}/privacy.html"
    privacy = f"""{crumbs_html([("Home", "index.html"), ("Privacy Policy", None)])}<h1>Privacy Policy · गोपनीयता नीति</h1><p class="muted">Last updated: {date.today().isoformat()}</p>
<div class="card"><p><strong>RailPariksha does not collect personal data.</strong> There is no sign-up. Your progress (answers, streaks,
settings) is stored only on your device and is deleted when you uninstall the app or use "Reset progress".</p>
<p>The app connects to the internet only to download updated question packs. No analytics, advertising identifiers or
location data are collected in this version.</p>
<p>If you choose to report a question or send feedback, your email app opens and you decide what to send to {SUPPORT_EMAIL}.</p>
<p>The app is an independent educational product and is not affiliated with Indian Railways, RRB or RPF.</p>
<p>Contact: {SUPPORT_EMAIL}</p></div>
<div class="card"><p><strong>RailPariksha कोई व्यक्तिगत जानकारी एकत्र नहीं करता।</strong> आपकी प्रगति केवल आपके फोन में सहेजी जाती है।
ऐप केवल नए प्रश्न पैक डाउनलोड करने के लिए इंटरनेट का उपयोग करता है।</p></div>"""
    write("privacy.html", page(f"Privacy Policy | {ORG_NAME}", "RailPariksha privacy policy", privacy, privacy_url, base),
          priority=0.3, changefreq="yearly")

    assets_src = ROOT / "docs/store/site_assets"
    if assets_src.exists():
        for f in assets_src.iterdir():
            shutil.copy(f, out / f.name)

    (out / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n", encoding="utf-8")
    today = date.today().isoformat()
    sitemap_entries = "".join(
        f"<url><loc>{base}/{name}</loc><lastmod>{today}</lastmod>"
        f"<changefreq>{freq}</changefreq><priority>{prio}</priority></url>"
        for name, prio, freq in url_meta
    )
    (out / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + sitemap_entries + "</urlset>\n",
        encoding="utf-8")
    print(f"site: {len(url_meta)} pages -> {out}")


if __name__ == "__main__":
    main()
