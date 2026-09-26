"""Static SEO site from the question bank: exam pages, topic practice pages, privacy policy, sitemap.

Usage: python pipeline/build_site.py --out site [--base-url https://example.github.io/repo]
"""
import argparse
import html
import json
import os
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
PLAY_URL = "https://play.google.com/store/apps/details?id=app.bharari"
SUPPORT_EMAIL = os.environ.get("SUPPORT_EMAIL", "support@bharari.app")
LETTERS = ["अ", "ब", "क", "ड"]

CSS = """
:root{--sky:#0B3D91;--sky2:#3A6FD8;--saffron:#FF8A00;--sun:#FFC04D;--bg:#F5F7FC;--card:#fff;--text:#16203a;--muted:#5b6479;--ok:#1E9E5A}
@media (prefers-color-scheme:dark){:root{--bg:#0E1320;--card:#1A2133;--text:#e8ecf5;--muted:#9aa3b8}}
*{box-sizing:border-box}body{margin:0;font-family:"Noto Sans Devanagari","Mukta",system-ui,sans-serif;background:var(--bg);color:var(--text);line-height:1.6}
a{color:var(--sky2)}header{background:linear-gradient(135deg,var(--sky),var(--sky2));color:#fff;padding:28px 16px}
header a{color:#fff;text-decoration:none}.wrap{max-width:860px;margin:0 auto;padding:0 16px}
h1{margin:.2em 0;font-size:1.8rem}.tag{color:var(--sun);font-weight:700}
.cta{display:inline-block;background:var(--saffron);color:#fff!important;font-weight:800;padding:12px 20px;border-radius:14px;text-decoration:none;margin-top:10px}
.card{background:var(--card);border-radius:18px;padding:16px 18px;margin:14px 0;box-shadow:0 2px 10px rgba(0,0,0,.05)}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}
.q{font-weight:700}.opts{margin:.4em 0 .6em;padding-left:0;list-style:none}.opts li{padding:2px 0}
details summary{cursor:pointer;color:var(--saffron);font-weight:700}.ans{color:var(--ok);font-weight:800}
.muted{color:var(--muted);font-size:.9rem}footer{padding:30px 16px;color:var(--muted);font-size:.9rem}
"""


def page(title, desc, body, canonical):
    return f"""<!doctype html><html lang="mr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)}</title><meta name="description" content="{html.escape(desc)}">
<link rel="canonical" href="{canonical}"><style>{CSS}</style></head><body>
<header><div class="wrap"><a href="index.html"><strong>भरारी · Bharari</strong></a>
<div class="tag">उंच भरारी घ्या · Fly high</div></div></header>
<main class="wrap">{body}
<div class="card"><strong>रोज सराव करा — मोफत ॲपवर!</strong><br>Daily 10, फ्लॅशकार्ड, मॉक टेस्ट, स्ट्रीक आणि बरेच काही.<br>
<a class="cta" href="{PLAY_URL}">Google Play वर डाउनलोड करा</a></div></main>
<footer class="wrap">भरारी हे स्वतंत्र शैक्षणिक ॲप आहे; कोणत्याही शासकीय विभागाशी संबंधित नाही. ·
<a href="privacy.html">Privacy Policy</a> · {SUPPORT_EMAIL}</footer></body></html>"""


def question_html(q, n):
    opts = "".join(f"<li>({LETTERS[i]}) {html.escape(o)}</li>" for i, o in enumerate(q["o_mr"]))
    extra = ""
    if q.get("hook_mr"):
        extra += f"<p>💡 {html.escape(q['hook_mr'])}</p>"
    return f"""<div class="card"><div class="q">{n}. {html.escape(q['q_mr'])}</div>
<div class="muted">{html.escape(q['q_en'])}</div><ul class="opts">{opts}</ul>
<details><summary>उत्तर व स्पष्टीकरण पहा</summary>
<p class="ans">उत्तर: ({LETTERS[q['a']]}) {html.escape(q['o_mr'][q['a']])}</p>
<p>{html.escape(q['e_mr'])}</p>{extra}<p class="muted">{html.escape(q['e_en'])}</p></details></div>"""


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
            body = (f"<h1>{html.escape(t['mr'])} — {html.escape(s['mr'])} सराव प्रश्न</h1>"
                    f"<p class='muted'>{html.escape(t['en'])} · {html.escape(s['en'])} MCQ with answers & explanation · "
                    f"{len(items)} प्रश्न</p>" + "".join(question_html(q, i + 1) for i, q in enumerate(items)))
            write(name, page(f"{t['mr']} ({t['en']}) सराव प्रश्न उत्तरांसह | {s['mr']} MCQ | Bharari",
                             f"{t['mr']} वर {len(items)} सराव प्रश्न, अचूक उत्तरे व सोपे स्पष्टीकरण. {s['en']} {t['en']} MCQ in Marathi.",
                             body, f"{base}/{name}"))

    # Exam pages
    exam_cards = []
    for e in tax["exams"]:
        links = []
        for sid in e["subjects"]:
            s = subjects.get(sid)
            if not s:
                continue
            tl = [f"<a href='{sid}-{t['id']}.html'>{html.escape(t['mr'])}</a> ({topic_counts[(sid, t['id'])]})"
                  for t in s["topics"] if (sid, t["id"]) in topic_counts]
            if tl:
                links.append(f"<div class='card'><strong>{html.escape(s['mr'])} · {html.escape(s['en'])}</strong><br>{' · '.join(tl)}</div>")
        if not links:
            continue
        name = f"exam-{e['id']}.html"
        neg = e.get("neg", 0)
        negtxt = "नकारात्मक गुणांकन नाही" if not neg else f"प्रत्येक चुकीच्या उत्तरासाठी {neg:g} गुण वजा (प्रश्नाच्या गुणांच्या प्रमाणात)"
        body = (f"<h1>{html.escape(e['mr'])} सराव प्रश्नसंच {date.today().year}</h1>"
                f"<p>{html.escape(e['en'])} practice questions in Marathi with answers and explanations. "
                f"<span class='muted'>({negtxt})</span></p>" + "".join(links))
        write(name, page(f"{e['mr']} सराव प्रश्न {date.today().year} | {e['en']} MCQ Marathi | Bharari",
                         f"{e['mr']} ({e['en']}) साठी विषयानुसार सराव प्रश्न, उत्तरे व स्पष्टीकरण. मोफत मॉक टेस्ट भरारी ॲपवर.",
                         body, f"{base}/{name}"))
        exam_cards.append(f"<a class='card' href='{name}'><strong>{html.escape(e['mr'])}</strong><br><span class='muted'>{html.escape(e['en'])}</span></a>")

    # Home
    body = ("<h1>महाराष्ट्रातील सर्व स्पर्धा परीक्षांसाठी मोफत सराव</h1>"
            "<p>पोलीस भरती, तलाठी, जिल्हा परिषद, MPSC, TET, SSC, रेल्वे, बँकिंग — विषयानुसार प्रश्न, अचूक उत्तरे आणि सोपे स्पष्टीकरण.</p>"
            f"<a class='cta' href='{PLAY_URL}'>ॲप डाउनलोड करा</a><h2>परीक्षा निवडा</h2><div class='grid'>{''.join(exam_cards)}</div>")
    write("index.html", page("भरारी — पोलीस भरती, तलाठी, MPSC सराव प्रश्न मराठीत | Bharari",
                             "Police Bharti, Talathi, MPSC, SSC practice questions in Marathi with answers & explanations. Free daily quiz, flashcards and mock tests.",
                             body, f"{base}/index.html"))

    privacy = f"""<h1>Privacy Policy · गोपनीयता धोरण</h1><p class="muted">Last updated: {date.today().isoformat()}</p>
<div class="card"><p><strong>Bharari does not collect personal data.</strong> There is no sign-up. Your progress (answers, streaks,
settings) is stored only on your device and is deleted when you uninstall the app or use "Reset progress".</p>
<p>The app connects to the internet only to download updated question packs. No analytics, advertising identifiers or
location data are collected in this version.</p>
<p>If you choose to report a question or send feedback, your email app opens and you decide what to send to {SUPPORT_EMAIL}.</p>
<p>The app is suitable for general audiences and is not affiliated with any government body.</p>
<p>Contact: {SUPPORT_EMAIL}</p></div>
<div class="card"><p><strong>भरारी कोणतीही वैयक्तिक माहिती गोळा करत नाही.</strong> तुमची प्रगती फक्त तुमच्या फोनमध्ये जतन होते.
ॲप फक्त नवीन प्रश्नसंच डाउनलोड करण्यासाठी इंटरनेट वापरते.</p></div>"""
    write("privacy.html", page("Privacy Policy | Bharari", "Bharari privacy policy", privacy, f"{base}/privacy.html"))

    (out / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n", encoding="utf-8")
    today = date.today().isoformat()
    (out / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
        + "".join(f"<url><loc>{u}</loc><lastmod>{today}</lastmod></url>" for u in urls) + "</urlset>\n",
        encoding="utf-8")
    print(f"site: {len(urls)} pages -> {out}")


if __name__ == "__main__":
    main()
