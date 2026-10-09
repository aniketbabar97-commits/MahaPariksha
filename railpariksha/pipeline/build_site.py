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
import re
import shutil
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
TELEGRAM_URL = os.environ.get("TELEGRAM_URL") or "https://t.me/RailParikshaApp"
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
:root{--navy:#0B3D91;--navy2:#154BAF;--gold:#F5B400;--sun:#FFD066;--bg:#F4F6FB;--card:#fff;--text:#16203a;--muted:#5b6479;--ok:#1E9E5A;--line:#e3e8f3;--shadow:0 2px 12px rgba(20,40,90,.07)}
@media (prefers-color-scheme:dark){:root{--bg:#0E1320;--card:#1A2133;--text:#e8ecf5;--muted:#9aa3b8;--line:#2a3350;--shadow:none;--navy2:#7aa7ff}}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;font-family:"Noto Sans Devanagari","Mukta",system-ui,-apple-system,"Segoe UI",sans-serif;background:var(--bg);color:var(--text);line-height:1.65;font-size:17px}
a{color:var(--navy2)}
.top{position:sticky;top:0;z-index:20;background:linear-gradient(135deg,#0B3D91,#154BAF);color:#fff;box-shadow:0 2px 10px rgba(0,0,0,.18)}
.top .in{max-width:1040px;margin:0 auto;padding:10px 16px;display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.top a{color:#fff;text-decoration:none}.brand{font-weight:800;font-size:1.15rem;letter-spacing:.2px}
.brand small{display:block;color:var(--sun);font-weight:600;font-size:.72rem;letter-spacing:.3px}
.nav{margin-left:auto;display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.nav a{padding:6px 11px;border-radius:999px;font-size:.92rem;font-weight:600}.nav a:hover{background:rgba(255,255,255,.14)}
.nav a.install{background:var(--gold);color:#16203a;font-weight:800}
.wrap{max-width:1040px;margin:0 auto;padding:0 16px}
main.wrap{padding-top:18px;padding-bottom:30px;max-width:900px}
h1{margin:.3em 0 .2em;font-size:1.75rem;line-height:1.3}h2{margin:1.7em 0 .5em;font-size:1.3rem}
.hero{background:linear-gradient(135deg,#0B3D91 0%,#1B56C6 100%);color:#fff;border-radius:22px;padding:26px 22px;margin:6px 0 10px;box-shadow:var(--shadow)}
.hero h1{color:#fff;font-size:2rem;margin:.1em 0 .25em}.hero p{margin:.2em 0 .8em;color:#e5eeff}
.badge{display:inline-block;background:rgba(255,255,255,.16);border-radius:999px;padding:3px 12px;font-size:.84rem;font-weight:700;color:var(--sun)}
.hero .row{display:flex;gap:10px;flex-wrap:wrap}.btn2{display:inline-block;border:2px solid rgba(255,255,255,.55);color:#fff!important;font-weight:700;padding:10px 18px;border-radius:14px;text-decoration:none}
.cta{display:inline-block;background:var(--gold);color:#16203a!important;font-weight:800;padding:12px 20px;border-radius:14px;text-decoration:none}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin:12px 0}
.stat{background:var(--card);border-radius:16px;padding:12px 14px;text-align:center;box-shadow:var(--shadow)}.stat b{display:block;font-size:1.45rem;color:var(--navy2)}.stat span{font-size:.85rem;color:var(--muted)}
.search{position:relative;margin:14px 0 4px}.search input{width:100%;padding:14px 16px;border:2px solid var(--line);border-radius:14px;font-size:1rem;background:var(--card);color:var(--text)}
.search input:focus{outline:none;border-color:var(--navy2)}
#hits{position:absolute;left:0;right:0;top:100%;background:var(--card);border-radius:14px;box-shadow:0 8px 28px rgba(0,0,0,.2);z-index:10;max-height:340px;overflow:auto;margin-top:6px}
#hits a{display:block;padding:10px 14px;text-decoration:none;color:var(--text);border-bottom:1px solid var(--line);font-size:.95rem}#hits a:hover{background:var(--bg)}
.card{background:var(--card);border-radius:18px;padding:16px 18px;margin:14px 0;box-shadow:var(--shadow);border:1px solid var(--line)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:12px}
.grid .card{margin:0;text-decoration:none;color:var(--text);display:block;transition:transform .12s,box-shadow .12s}.grid .card:hover{transform:translateY(-2px);box-shadow:0 6px 18px rgba(20,40,90,.14)}
.tile .ic{font-size:1.7rem;display:block;margin-bottom:2px}
.chips{display:flex;flex-wrap:wrap;gap:8px}.chips a{background:var(--card);border:1px solid var(--line);padding:7px 14px;border-radius:999px;text-decoration:none;font-weight:600;font-size:.92rem}.chips a:hover{border-color:var(--navy2)}
.steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}.steps .card{margin:0}.steps b{font-size:1.1rem;color:var(--navy2)}
.q{font-weight:700;font-size:1.05rem}.opts{margin:.5em 0 .7em;padding-left:0;list-style:none;display:grid;gap:6px}
.opts li{padding:8px 12px;border:1px solid var(--line);border-radius:12px;background:var(--bg)}
details summary{cursor:pointer;color:var(--navy2);font-weight:800;padding:6px 0}.ans{color:var(--ok);font-weight:800}
.muted{color:var(--muted);font-size:.92rem}
.answer{background:var(--card);border-left:4px solid var(--gold);border-radius:10px;padding:12px 16px;margin:12px 0 18px;font-size:1rem}
.crumbs{font-size:.86rem;color:var(--muted);margin-bottom:6px}.crumbs a{color:var(--muted)}
.links{margin:.3em 0}.faq dt{font-weight:700;margin-top:10px}.faq dd{margin:.2em 0 0}
.pager{display:flex;justify-content:space-between;gap:10px;margin:18px 0;flex-wrap:wrap}.pager a{background:var(--card);border:1px solid var(--line);padding:9px 16px;border-radius:12px;text-decoration:none;font-weight:700}
.appcta{background:linear-gradient(135deg,#0B3D91,#1B56C6);color:#fff;border-radius:18px;padding:18px;margin:22px 0;text-align:center}.appcta a.cta{margin:4px}
footer{background:var(--card);border-top:1px solid var(--line);padding:26px 16px;color:var(--muted);font-size:.9rem;margin-top:30px}
footer .cols{max-width:1040px;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:18px}footer a{color:var(--muted)}footer h4{margin:.1em 0 .4em;color:var(--text)}
@media (max-width:560px){.hero h1{font-size:1.55rem}body{font-size:16px}.nav a:not(.install){display:none}}
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


ADSENSE_CLIENT = os.environ.get("ADSENSE_CLIENT", "")  # e.g. ca-pub-1234567890123456; empty = no ads at all
ADSENSE_SLOT = os.environ.get("ADSENSE_SLOT", "")


def ad_unit():
    """One responsive AdSense unit, or nothing until the site is approved and the two env values are set."""
    if not (ADSENSE_CLIENT and ADSENSE_SLOT):
        return ""
    return (f'<div class="muted" style="text-align:center;margin:14px 0">विज्ञापन · Advertisement'
            f'<ins class="adsbygoogle" style="display:block" data-ad-client="{ADSENSE_CLIENT}" '
            f'data-ad-slot="{ADSENSE_SLOT}" data-ad-format="auto" data-full-width-responsive="true"></ins>'
            f'<script>(adsbygoogle=window.adsbygoogle||[]).push({{}});</script></div>')


def page(title, desc, body, canonical, base, structured="", og_type="website"):
    ads_head = (f'<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client='
                f'{ADSENSE_CLIENT}" crossorigin="anonymous"></script>') if ADSENSE_CLIENT else ""
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
<style>{CSS}</style>{structured}{ads_head}</head><body>
<header class="top"><div class="in"><a class="brand" href="/">RailPariksha · रेलपरीक्षा<small>स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए</small></a>
<nav class="nav"><a href="/#exams">परीक्षाएँ</a><a href="/#papers">पिछले प्रश्न पत्र</a><a href="/#subjects">विषय</a><a href="{TELEGRAM_URL}">Telegram</a><a class="install" href="{PLAY_URL}">ऐप इंस्टॉल करें</a></nav></div></header>
<main class="wrap">{body}
<div class="appcta"><strong>रोज़ मुफ़्त अभ्यास करें!</strong><br>Daily 10, फ्लैशकार्ड, मॉक टेस्ट, स्ट्रीक और 45,000+ असली PYQ, हिंदी व अंग्रेज़ी में।<br>
<a class="cta" href="{PLAY_URL}">Google Play से डाउनलोड करें</a> <a class="btn2" href="{TELEGRAM_URL}">Telegram चैनल जुड़ें</a></div></main>
<footer><div class="cols"><div><h4>RailPariksha</h4>स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए बनाया गया मुफ़्त अभ्यास ऐप।</div>
<div><h4>लिंक</h4><a href="/">होम</a><br><a href="{PLAY_URL}">Google Play</a><br><a href="{TELEGRAM_URL}">Telegram</a><br><a href="privacy.html">Privacy Policy</a></div>
<div><h4>सूचना</h4>RailPariksha एक स्वतंत्र शैक्षणिक ऐप है; भारतीय रेलवे, RRB या RPF से संबद्ध नहीं है। आधिकारिक सूचनाएँ आधिकारिक साइट पर देखें।<br>{SUPPORT_EMAIL}</div></div></footer></body></html>"""


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


def clean_urls(base):
    """Cloudflare (workers.dev / pages.dev) answers /x.html with a redirect to /x, so links and the sitemap must
    already use the extension-less address. CLEAN_URLS=1 forces it, CLEAN_URLS=0 forbids it."""
    flag = os.environ.get("CLEAN_URLS")
    if flag in ("0", "1"):
        return flag == "1"
    return base.split("//")[-1].split("/")[0].endswith((".workers.dev", ".pages.dev"))


def strip_html_extensions(out):
    for f in list(out.glob("*.html")) + [out / "sitemap.xml"]:
        t = f.read_text(encoding="utf-8")
        t = t.replace('"index.html"', '"/"').replace("'index.html'", "'/'").replace("/index.html", "/")
        for q in ('"', "'", "#", "<"):
            t = t.replace(".html" + q, q)
        f.write_text(t, encoding="utf-8")


EXAM_ICONS = {"rrb_ntpc": "🚉", "rrb_group_d": "🛤️", "rrb_alp": "🚂", "rrb_technician": "🔧", "rrb_je": "🏗️",
              "rrb_je_mechanical": "⚙️", "rrb_je_civil": "🧱", "rrb_je_electrical": "⚡", "rrb_paramedical": "🩺",
              "rpf_constable": "🛡️", "rpf_si": "🎖️", "dfccil_executive": "📦"}
SUBJECT_ICONS = {"maths": "➗", "reasoning": "🧩", "science": "🔬", "gk": "🌍", "railway_gk": "🚆", "computer": "💻",
                 "english": "🔤", "current_affairs": "📰"}

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

    search_index = []

    def write(name, content, priority=0.5, changefreq="monthly"):
        (out / name).write_text(content, encoding="utf-8")
        m = re.search(r"<title>(.*?)</title>", content)
        if m and name != "privacy.html":
            search_index.append([html.unescape(m.group(1)).split(" | ")[0], name])
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
        exam_cards.append(f"<a class='card tile' href='{name}'><span class='ic'>{EXAM_ICONS.get(e['id'], '📘')}</span><strong>{esc(e['hi'])}</strong><br><span class='muted'>{esc(e['en'])}</span></a>")

    # ---- Previous-year papers ---------------------------------------
    import site_pyq
    pyq_cards = site_pyq.add_pyq_pages(
        dict(page=page, esc=esc, question_html=question_html, crumbs_html=crumbs_html, json_ld=json_ld,
             breadcrumb_ld=breadcrumb_ld, faq_ld=faq_ld, ad_unit=ad_unit, ORG_NAME=ORG_NAME),
        tax, CONTENT, base, write)

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
    total_pyq = sum(len(v) for sub in site_pyq.load(CONTENT).values() for paper in sub.values() for v in paper.values())
    n_papers = sum(len(sub) for sub in site_pyq.load(CONTENT).values())
    subject_chips = "".join(f"<a href='subject-{s2['id']}.html'>{SUBJECT_ICONS.get(s2['id'], '📘')} {esc(s2['hi'])}</a>"
                            for s2 in tax["subjects"] if any((s2["id"], t["id"]) in topic_pages for t in s2["topics"]))
    body = (
        "<section class='hero'><span class='badge'>स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए 🤝</span>"
        "<h1>रेलवे परीक्षा की तैयारी, बिल्कुल मुफ़्त</h1>"
        "<p>RRB NTPC, ग्रुप D, ALP, JE, RPF के असली पिछले साल के प्रश्न, सही उत्तर और सरल हिंदी-अंग्रेज़ी व्याख्या के साथ। "
        "Free practice for every major railway exam, in Hindi and English.</p>"
        f"<div class='row'><a class='cta' href='{PLAY_URL}'>ऐप डाउनलोड करें</a><a class='btn2' href='{TELEGRAM_URL}'>Telegram चैनल</a></div></section>"
        f"<div class='stats'><div class='stat'><b>{total_pyq:,}</b><span>असली PYQ प्रश्न</span></div>"
        f"<div class='stat'><b>{n_papers}</b><span>पिछले प्रश्न पत्र</span></div>"
        f"<div class='stat'><b>{len(tax['exams'])}</b><span>परीक्षाएँ</span></div>"
        "<div class='stat'><b>हिंदी + EN</b><span>हर प्रश्न दोनों भाषा में</span></div></div>"
        "<div class='search'><input id='q' type='search' placeholder='खोजें: जैसे NTPC 2025, गणित, Group D…' autocomplete='off' aria-label='Search'><div id='hits' hidden></div></div>"
        "<h2 id='exams'>आप किस परीक्षा की तैयारी कर रहे हैं? · Choose your exam</h2>"
        f"<div class='grid'>{''.join(exam_cards)}</div>"
        "<h2 id='papers'>पिछले साल के प्रश्न पत्र · Previous year papers</h2>"
        f"<div class='grid'>{pyq_cards}</div>"
        "<h2 id='subjects'>विषय के अनुसार अभ्यास · Practice by subject</h2>"
        f"<div class='chips'>{subject_chips}</div>"
        "<h2>कैसे काम करता है · How it works</h2><div class='steps'>"
        "<div class='card'><b>1. परीक्षा चुनें</b><br>अपनी परीक्षा चुनें और उसका सिलेबस व पैटर्न देखें।</div>"
        "<div class='card'><b>2. रोज़ अभ्यास करें</b><br>Daily 10, टॉपिक टेस्ट और असली PYQ, व्याख्या के साथ।</div>"
        "<div class='card'><b>3. मॉक टेस्ट दें</b><br>ऐप में टाइमर और सही नेगेटिव मार्किंग के साथ पूरा मॉक।</div></div>"
        + answer_para)
    search_js = ("<script>(function(){var i=document.getElementById('q'),h=document.getElementById('hits'),d=null;"
                 "function load(c){if(d)return c();fetch('search.json').then(function(r){return r.json()}).then(function(j){d=j;c()})}"
                 "i.addEventListener('input',function(){var t=i.value.trim().toLowerCase();if(t.length<2){h.hidden=true;return}"
                 "load(function(){var w=t.split(/\\s+/),o=[];for(var k=0;k<d.length&&o.length<12;k++){var s=d[k][0].toLowerCase(),m=true;"
                 "for(var x=0;x<w.length;x++){if(s.indexOf(w[x])<0){m=false;break}}if(m)o.push(d[k])}"
                 "h.innerHTML=o.length?o.map(function(e){return '<a href=\"'+e[1]+'\">'+e[0]+'</a>'}).join(''):'<a>कुछ नहीं मिला</a>';h.hidden=false})})})();</script>")
    body += search_js
    write("index.html", page(f"{ORG_NAME} — RRB NTPC, ग्रुप डी, RPF अभ्यास प्रश्न हिंदी में",
                             "RRB NTPC, Group D, ALP, JE, RPF Constable & SI practice questions in Hindi with answers & explanations. Free daily quiz, flashcards and mock tests.",
                             body, home_url, base, structured), priority=1.0, changefreq="weekly")

    privacy_url = f"{base}/privacy.html"
    privacy = f"""{crumbs_html([("Home", "index.html"), ("Privacy Policy", None)])}<h1>Privacy Policy · गोपनीयता नीति</h1><p class="muted">Last updated: {date.today().isoformat()}</p>
<div class="card"><p><strong>Account and data.</strong> There is no sign-up. In the app, your progress (answers, streaks,
settings) is stored on your phone. If you choose to sign in with Google, a backup of your progress is stored in our Firebase
project under your account so it can be restored on a new phone, and you can delete it any time from the app.</p>
<p><strong>Ads.</strong> The app and this website show ads served by Google (AdMob in the app, AdSense on the website). Google and its
partners may use cookies or advertising identifiers to show and measure ads; you can control personalised ads in your Google
account settings or your phone's ad settings, and learn how Google uses data at policies.google.com/technologies/partner-sites.</p>
<p><strong>Analytics and crash reports.</strong> The app uses Firebase Analytics (which screens and features are used) and Crashlytics (crash
reports) to find and fix problems. You can send an error report on any question; it contains the question and your note, not your name.</p>
<p>If you send feedback, your email app opens and you decide what to send to {SUPPORT_EMAIL}.</p>
<p>The app and website are an independent educational product, not affiliated with Indian Railways, RRB or RPF.</p>
<p>Contact: {SUPPORT_EMAIL}</p></div>
<div class="card"><p><strong>RailPariksha कोई व्यक्तिगत जानकारी एकत्र नहीं करता।</strong> आपकी प्रगति केवल आपके फोन में सहेजी जाती है।
ऐप और वेबसाइट पर Google द्वारा विज्ञापन दिखाए जाते हैं (ऐप में AdMob, वेबसाइट पर AdSense); ये कुकीज़/विज्ञापन आईडी का उपयोग कर सकते हैं। ऐप में Firebase Analytics और Crashlytics का उपयोग होता है। Google से साइन इन करने पर ही आपकी प्रगति का बैकअप सुरक्षित होता है।</p></div>"""
    write("privacy.html", page(f"Privacy Policy | {ORG_NAME}", "RailPariksha privacy policy", privacy, privacy_url, base),
          priority=0.3, changefreq="yearly")

    assets_src = ROOT / "docs/store/site_assets"
    if assets_src.exists():
        for f in assets_src.iterdir():
            shutil.copy(f, out / f.name)

    # app-ads.txt lets AdMob confirm the app's ads are sold by this developer; it must sit at the site root.
    (out / "app-ads.txt").write_text("google.com, pub-9100209280220037, DIRECT, f08c47fec0942fa0\n", encoding="utf-8")
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
    clean = clean_urls(base)
    entries = [[t, ("/" if n == "index.html" else (n[:-5] if clean else n))] for t, n in search_index]
    (out / "search.json").write_text(json.dumps(entries, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    if clean:
        strip_html_extensions(out)
    print(f"site: {len(url_meta)} pages -> {out}")


if __name__ == "__main__":
    main()
