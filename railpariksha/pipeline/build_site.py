"""Static SEO site from the question bank: exam pages, topic practice pages, privacy policy, sitemap.

Usage: python pipeline/build_site.py --out site [--base-url https://example.github.io/repo]
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
"""


def page(title, desc, body, canonical):
    return f"""<!doctype html><html lang="hi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="description" content="{html.escape(desc)}">
<link rel="canonical" href="{canonical}">
<link rel="icon" href="favicon-32.png" sizes="32x32">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta property="og:type" content="website"><meta property="og:site_name" content="RailPariksha">
<meta property="og:title" content="{html.escape(title)}"><meta property="og:description" content="{html.escape(desc)}">
<meta property="og:image" content="{canonical.rsplit('/', 1)[0]}/og-image.png">
<meta name="twitter:card" content="summary_large_image">
<style>{CSS}</style></head><body>
<header><div class="wrap"><a href="index.html"><strong>RailPariksha · रेलपरीक्षा</strong></a>
<div class="tag">Train to succeed · सफलता की पटरी पर</div></div></header>
<main class="wrap">{body}
<div class="card"><strong>रोज़ मुफ़्त अभ्यास करें!</strong><br>Daily 10, फ्लैशकार्ड, मॉक टेस्ट, स्ट्रीक और भी बहुत कुछ।<br>
<a class="cta" href="{PLAY_URL}">Google Play से डाउनलोड करें</a></div></main>
<footer class="wrap">RailPariksha एक स्वतंत्र शैक्षणिक ऐप है; भारतीय रेलवे, RRB या RPF से संबद्ध नहीं है। ·
<a href="privacy.html">Privacy Policy</a> · {SUPPORT_EMAIL}</footer></body></html>"""


def question_html(q, n):
    opts = "".join(f"<li>({LETTERS[i]}) {html.escape(o)}</li>" for i, o in enumerate(q["o_hi"]))
    extra = ""
    if q.get("hook_hi"):
        extra += f"<p>💡 {html.escape(q['hook_hi'])}</p>"
    return f"""<div class="card"><div class="q">{n}. {html.escape(q['q_hi'])}</div>
<div class="muted">{html.escape(q['q_en'])}</div><ul class="opts">{opts}</ul>
<details><summary>उत्तर व स्पष्टीकरण देखें</summary>
<p class="ans">उत्तर: ({LETTERS[q['a']]}) {html.escape(q['o_hi'][q['a']])}</p>
<p>{html.escape(q['e_hi'])}</p>{extra}<p class="muted">{html.escape(q['e_en'])}</p></details></div>"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="site")
    ap.add_argument("--base-url", default=os.environ.get("SITE_URL", ""))
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    base = a.base_url.rstrip("/")
    tax = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    qs = []
    for p in sorted((CONTENT / "bank").glob("*.json")):
        qs.extend(json.loads(p.read_text(encoding="utf-8")))
    subjects = {s["id"]: s for s in tax["subjects"]}
    urls = []

    def write(name, content):
        (out / name).write_text(content, encoding="utf-8")
        urls.append(f"{base}/{name}")

    # Topic pages
    topic_counts = {}
    for s in tax["subjects"]:
        for t in s["topics"]:
            items = [q for q in qs if q["s"] == s["id"] and q["t"] == t["id"]]
            if not items:
                continue
            topic_counts[(s["id"], t["id"])] = len(items)
            name = f"{s['id']}-{t['id']}.html"
            body = (f"<h1>{html.escape(t['hi'])} — {html.escape(s['hi'])} अभ्यास प्रश्न</h1>"
                    f"<p class='muted'>{html.escape(t['en'])} · {html.escape(s['en'])} MCQ with answers & explanation · "
                    f"{len(items)} प्रश्न</p>" + "".join(question_html(q, i + 1) for i, q in enumerate(items)))
            write(name, page(f"{t['hi']} ({t['en']}) अभ्यास प्रश्न उत्तर सहित | {s['hi']} MCQ | RailPariksha",
                             f"{t['hi']} पर {len(items)} अभ्यास प्रश्न, सही उत्तर व सरल स्पष्टीकरण। {s['en']} {t['en']} MCQ in Hindi.",
                             body, f"{base}/{name}"))

    # Exam pages
    exam_cards = []
    for e in tax["exams"]:
        links = []
        for sid in e["subjects"]:
            s = subjects.get(sid)
            if not s:
                continue
            tl = [f"<a href='{sid}-{t['id']}.html'>{html.escape(t['hi'])}</a> ({topic_counts[(sid, t['id'])]})"
                  for t in s["topics"] if (sid, t["id"]) in topic_counts]
            if tl:
                links.append(f"<div class='card'><strong>{html.escape(s['hi'])} · {html.escape(s['en'])}</strong><br>{' · '.join(tl)}</div>")
        if not links:
            continue
        name = f"exam-{e['id']}.html"
        neg = e.get("neg", 0)
        negtxt = "कोई नकारात्मक अंकन नहीं" if not neg else f"प्रत्येक गलत उत्तर पर {neg:g} अंक की कटौती"
        body = (f"<h1>{html.escape(e['hi'])} अभ्यास प्रश्न {date.today().year}</h1>"
                f"<p>{html.escape(e['en'])} practice questions in Hindi with answers and explanations. "
                f"<span class='muted'>({negtxt})</span></p>" + "".join(links))
        write(name, page(f"{e['hi']} अभ्यास प्रश्न {date.today().year} | {e['en']} MCQ Hindi | RailPariksha",
                         f"{e['hi']} ({e['en']}) के लिए विषयवार अभ्यास प्रश्न, उत्तर व स्पष्टीकरण। RailPariksha ऐप पर मुफ़्त मॉक टेस्ट।",
                         body, f"{base}/{name}"))
        exam_cards.append(f"<a class='card' href='{name}'><strong>{html.escape(e['hi'])}</strong><br><span class='muted'>{html.escape(e['en'])}</span></a>")

    # Home
    body = ("<h1>रेलवे व RPF परीक्षाओं के लिए मुफ़्त अभ्यास</h1>"
            "<p>RRB NTPC, ग्रुप डी, ALP, JE, RPF कांस्टेबल व SI — विषयवार प्रश्न, सही उत्तर और सरल स्पष्टीकरण।</p>"
            f"<a class='cta' href='{PLAY_URL}'>ऐप डाउनलोड करें</a><h2>परीक्षा चुनें</h2><div class='grid'>{''.join(exam_cards)}</div>")
    write("index.html", page("RailPariksha — RRB NTPC, ग्रुप डी, RPF अभ्यास प्रश्न हिंदी में",
                             "RRB NTPC, Group D, ALP, JE, RPF Constable & SI practice questions in Hindi with answers & explanations. Free daily quiz, flashcards and mock tests.",
                             body, f"{base}/index.html"))

    privacy = f"""<h1>Privacy Policy · गोपनीयता नीति</h1><p class="muted">Last updated: {date.today().isoformat()}</p>
<div class="card"><p><strong>RailPariksha does not collect personal data.</strong> There is no sign-up. Your progress (answers, streaks,
settings) is stored only on your device and is deleted when you uninstall the app or use "Reset progress".</p>
<p>The app connects to the internet only to download updated question packs. No analytics, advertising identifiers or
location data are collected in this version.</p>
<p>If you choose to report a question or send feedback, your email app opens and you decide what to send to {SUPPORT_EMAIL}.</p>
<p>The app is an independent educational product and is not affiliated with Indian Railways, RRB or RPF.</p>
<p>Contact: {SUPPORT_EMAIL}</p></div>
<div class="card"><p><strong>RailPariksha कोई व्यक्तिगत जानकारी एकत्र नहीं करता।</strong> आपकी प्रगति केवल आपके फोन में सहेजी जाती है।
ऐप केवल नए प्रश्न पैक डाउनलोड करने के लिए इंटरनेट का उपयोग करता है।</p></div>"""
    write("privacy.html", page("Privacy Policy | RailPariksha", "RailPariksha privacy policy", privacy, f"{base}/privacy.html"))

    assets_src = ROOT / "docs/store/site_assets"
    if assets_src.exists():
        for f in assets_src.iterdir():
            shutil.copy(f, out / f.name)

    (out / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n", encoding="utf-8")
    today = date.today().isoformat()
    (out / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + "".join(f"<url><loc>{u}</loc><lastmod>{today}</lastmod></url>" for u in urls) + "</urlset>\n",
        encoding="utf-8")
    print(f"site: {len(urls)} pages -> {out}")


if __name__ == "__main__":
    main()
