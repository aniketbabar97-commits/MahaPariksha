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
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import links  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
TELEGRAM_URL = os.environ.get("TELEGRAM_URL") or "https://t.me/RailParikshaApp"
YOUTUBE_URL = "https://www.youtube.com/@RailPariksha_Official"
PLAY_URL = links.PLAY_STORE_URL
APP_PAGE = "app.html"  # CTAs go through our own /app page (see links.py), never straight to a Play page that may 404
SUPPORT_EMAIL = os.environ.get("SUPPORT_EMAIL", "support@railpariksha.in")
LETTERS = ["अ", "ब", "क", "ड"]
ORG_NAME = "RailPariksha"
# The production address. Canonical/OG/JSON-LD URLs and the sitemap must be absolute (sitemap protocol,
# schema.org). SITE_URL / --base-url can override it, except for preview addresses (workers.dev, pages.dev):
# those are never the canonical home, so they always fall back to this one.
DEFAULT_BASE_URL = "https://railpariksha.in"
PREVIEW_HOSTS = (".workers.dev", ".pages.dev")

# Known negative-marking fractions, spelled out for direct-answer / FAQ text.
# Sourced from taxonomy.json's "neg" field on each exam (RRB = 1/3, RPF/PSU = 1/4).
NEG_FRACTIONS = {0.3333: "1/3", 0.25: "1/4", 0: None}

CSS = """
:root{--navy:#0A1633;--navy2:#154BAF;--gold:#E8BA4A;--sun:#F3D27C;--bg:#FAF8F2;--card:#fff;--text:#1b2236;--muted:#5d6475;--ok:#1E9E5A;--line:#e7e2d3;--shadow:0 2px 12px rgba(40,40,20,.07)}
@media (prefers-color-scheme:dark){:root{--bg:#0A1226;--card:#131E3D;--text:#e8ecf5;--muted:#9aa3b8;--line:#2a3350;--shadow:none;--navy2:#7aa7ff}}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;font-family:"Noto Sans Devanagari","Mukta",system-ui,-apple-system,"Segoe UI",sans-serif;background:var(--bg);color:var(--text);line-height:1.65;font-size:17px}
a{color:var(--navy2)}
.top{position:sticky;top:0;z-index:20;background:linear-gradient(135deg,#0A1633,#14264F);color:#fff;box-shadow:0 2px 10px rgba(0,0,0,.18)}
.top .in{max-width:1040px;margin:0 auto;padding:10px 16px;display:flex;align-items:center;gap:14px;flex-wrap:wrap}
.top a{color:#fff;text-decoration:none}.brand{font-weight:800;font-size:1.15rem;letter-spacing:.2px}
.brand small{display:block;color:var(--sun);font-weight:600;font-size:.72rem;letter-spacing:.3px}
.nav{margin-left:auto;display:flex;gap:6px;align-items:center;flex-wrap:wrap}
.nav a{padding:6px 11px;border-radius:999px;font-size:.92rem;font-weight:600}.nav a:hover{background:rgba(255,255,255,.14)}
.nav a.install{background:var(--gold);color:#16203a;font-weight:800}
.wrap{max-width:1040px;margin:0 auto;padding:0 16px}
main.wrap{padding-top:18px;padding-bottom:30px;max-width:900px}
h1{margin:.3em 0 .2em;font-size:1.75rem;line-height:1.3}h2{margin:1.7em 0 .5em;font-size:1.3rem}
.hero{background:linear-gradient(135deg,#0A1633 0%,#17305E 100%);color:#fff;border-radius:22px;padding:26px 22px;margin:6px 0 10px;box-shadow:var(--shadow)}
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
.appcta{background:linear-gradient(135deg,#0A1633,#17305E);color:#fff;border-radius:18px;padding:18px;margin:22px 0;text-align:center}.appcta a.cta{margin:4px}
footer{background:var(--card);border-top:1px solid var(--line);padding:26px 16px;color:var(--muted);font-size:.9rem;margin-top:30px}
footer .cols{max-width:1040px;margin:0 auto;display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:18px}footer a{color:var(--muted)}footer h3{margin:.1em 0 .4em;color:var(--text)}
@media (max-width:560px){.top .in{flex-wrap:nowrap}.brand small{display:none}.brand{font-size:1.02rem}.hero h1{font-size:1.55rem}body{font-size:16px}.nav a:not(.install):not(.lang){display:none}}

/* ---- brand + motion ---- */
.brand{display:flex;align-items:center;gap:10px}.brand img{width:42px;height:42px;border-radius:11px;box-shadow:0 2px 8px rgba(0,0,0,.3);transition:transform .3s}
.brand:hover img{transform:rotate(-6deg) scale(1.06)}.brand span{line-height:1.15}
.top{transition:padding .2s,box-shadow .2s}.top.sm .in{padding-top:6px;padding-bottom:6px}.top.sm .brand img{width:34px;height:34px}
.hero{position:relative;overflow:hidden;background:linear-gradient(120deg,#0A1633,#14264F,#183463,#0F2247);background-size:300% 300%;animation:bg 14s ease infinite;display:grid;grid-template-columns:1.3fr .8fr;gap:10px;align-items:center;padding:30px 26px 0}
.hero:before,.hero:after{content:"";position:absolute;border-radius:50%;background:rgba(255,255,255,.07);animation:drift 11s ease-in-out infinite}
.hero:before{width:260px;height:260px;right:-60px;top:-80px}.hero:after{width:180px;height:180px;left:-50px;bottom:40px;animation-delay:-5s}
.hero .txt{position:relative;z-index:2;padding-bottom:20px}
.hero .logo{position:relative;z-index:2;justify-self:center;width:min(230px,100%);height:auto;aspect-ratio:1/1;animation:float 5s ease-in-out infinite;filter:drop-shadow(0 14px 22px rgba(0,0,0,.35));border-radius:0}
.glow{position:absolute;z-index:1;right:9%;top:18%;width:230px;height:230px;border-radius:50%;background:radial-gradient(circle,rgba(255,208,102,.45),transparent 65%);animation:pulse 3.6s ease-in-out infinite}
.track{grid-column:1/-1;position:relative;height:74px;margin:0 -26px;overflow:hidden;z-index:2}
.train{position:absolute;bottom:14px;left:0;width:210px;animation:ride 16s linear infinite}
.rails{position:absolute;left:0;right:0;bottom:0;height:16px;background:repeating-linear-gradient(90deg,#9fb6e6 0 3px,transparent 3px 22px);opacity:.9;animation:ties 1.1s linear infinite;border-top:3px solid #dbe6ff}
.tick{overflow:hidden;white-space:nowrap;border-radius:14px;background:var(--card);border:1px solid var(--line);margin:12px 0;padding:10px 0;box-shadow:var(--shadow)}
.tick div{display:inline-block;animation:marq 40s linear infinite;font-weight:700;color:var(--navy2)}.tick:hover div{animation-play-state:paused}
.rv{opacity:0;transform:translateY(22px);transition:opacity .6s ease,transform .6s ease}.rv.in{opacity:1;transform:none}
.tile .ic{display:inline-block;transition:transform .25s}.tile:hover .ic{transform:scale(1.25) rotate(-8deg)}
.stat b{font-variant-numeric:tabular-nums}.btn2,.cta{transition:transform .15s,box-shadow .15s}.cta:hover,.btn2:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(0,0,0,.25)}
.cta.pulse{animation:cta 2.4s ease-in-out infinite}
@keyframes bg{0%,100%{background-position:0 50%}50%{background-position:100% 50%}}
@keyframes drift{0%,100%{transform:translate(0,0)}50%{transform:translate(18px,14px)}}
@keyframes float{0%,100%{transform:translateY(0) rotate(-1.5deg)}50%{transform:translateY(-12px) rotate(1.5deg)}}
@keyframes pulse{0%,100%{opacity:.55;transform:scale(.92)}50%{opacity:1;transform:scale(1.08)}}
@keyframes ride{0%{transform:translateX(-230px)}100%{transform:translateX(calc(100vw + 40px))}}
@keyframes ties{to{background-position:-22px 0}}
@keyframes marq{to{transform:translateX(-50%)}}
@keyframes cta{0%,100%{box-shadow:0 0 0 0 rgba(245,180,0,.55)}60%{box-shadow:0 0 0 14px rgba(245,180,0,0)}}
@media (max-width:640px){.hero{grid-template-columns:1fr;padding:22px 18px 0}.hero .logo{width:130px;order:-1;justify-self:start}.glow{display:none}.track{margin:0 -18px}.train{width:150px}}
@media (prefers-reduced-motion:reduce){*,*:before,*:after{animation:none!important;transition:none!important}.rv{opacity:1;transform:none}}
.quote{background:linear-gradient(135deg,#fff8e1,#fff);border-left:5px solid var(--gold);font-size:1.12rem}
@media (prefers-color-scheme:dark){.quote{background:linear-gradient(135deg,#2a2410,#1A2133)}}
.feat .ic{font-size:1.5rem;display:block}.feats .card{cursor:default}.feats .card:hover .ic{animation:wob .6s}
@keyframes wob{25%{transform:rotate(-12deg)}75%{transform:rotate(12deg)}}

/* ---- language switch ---- */
html[lang="en"] .hi,html[lang="hi"] .en{display:none}
.bi{display:flex;flex-direction:column;gap:2px}
html[lang="hi"] .bi .L-hi,html[lang="en"] .bi .L-en{order:1}
html[lang="hi"] .bi .L-en,html[lang="en"] .bi .L-hi{order:2;color:var(--muted);font-size:.9em}
.lang{border:2px solid rgba(255,255,255,.6);background:transparent;color:#fff;border-radius:999px;padding:5px 12px;font-weight:800;cursor:pointer;font-size:.9rem}
.lang:hover{background:rgba(255,255,255,.16)}
a.lang{display:inline-flex;align-items:center;text-decoration:none}
.q .bi{font-weight:700}.opts li .bi{font-weight:500}

@font-face{font-family:"Mukta";font-weight:400;font-display:swap;src:url(/mukta-400.woff2) format("woff2"),url(/mukta-400.woff) format("woff")}
@font-face{font-family:"Mukta";font-weight:700;font-display:swap;src:url(/mukta-700.woff2) format("woff2"),url(/mukta-700.woff) format("woff")}
body{font-family:"Mukta","Noto Sans Devanagari",system-ui,-apple-system,"Segoe UI",sans-serif;font-size:18px;line-height:1.6;letter-spacing:.005em}
h1,h2,h3,b,strong{font-weight:700}
h2{position:relative;padding-left:14px;margin:2em 0 .7em;font-size:1.38rem}
h2:before{content:"";position:absolute;left:0;top:.2em;bottom:.2em;width:5px;border-radius:4px;background:linear-gradient(var(--gold),#ff9d00)}
main.wrap{max-width:980px;padding-top:22px}
.trust{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0 4px}.trust>span{background:rgba(255,255,255,.14);border-radius:999px;padding:4px 12px;font-size:.88rem;font-weight:700;color:#fff}
.opts li{cursor:pointer;transition:background .15s,border-color .15s,transform .1s}.opts li:hover{border-color:var(--navy2);transform:translateX(2px)}
.opts li.ok{background:#e6f6ec;border-color:#1E9E5A}.opts li.bad{background:#fdeaea;border-color:#d64545}
@media (prefers-color-scheme:dark){.opts li.ok{background:#12301f}.opts li.bad{background:#3a1a1a}}
.opts.done li{cursor:default;transform:none}
.try{background:var(--card);border:1px solid var(--line);border-radius:22px;padding:20px;box-shadow:var(--shadow)}
.try .meta{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap;color:var(--muted);font-size:.9rem;margin-bottom:8px}
.try .qq{font-weight:700;font-size:1.12rem;margin:6px 0 12px}
.try .opt{display:block;width:100%;text-align:left;font:inherit;color:inherit;background:var(--bg);border:2px solid var(--line);border-radius:14px;padding:11px 14px;margin:8px 0;cursor:pointer;transition:all .15s}
.try .opt:hover{border-color:var(--navy2);transform:translateX(3px)}.try .opt.ok{background:#e6f6ec;border-color:#1E9E5A}.try .opt.bad{background:#fdeaea;border-color:#d64545}
@media (prefers-color-scheme:dark){.try .opt.ok{background:#12301f}.try .opt.bad{background:#3a1a1a}}
.try .res{margin-top:12px;display:none}.try.done .res{display:block;animation:rise .35s ease}
.try .row2{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}.try .row2 a,.try .row2 button{font:inherit;font-weight:700;border-radius:12px;padding:9px 16px;cursor:pointer;text-decoration:none;border:2px solid var(--navy2);background:transparent;color:var(--navy2)}
.try .row2 a.cta{background:var(--gold);border-color:var(--gold);color:#16203a}
@keyframes rise{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}
.shots{display:flex;gap:16px;overflow-x:auto;scroll-snap-type:x mandatory;padding:6px 4px 18px;margin:0 -4px;-webkit-overflow-scrolling:touch}
.shots figure{flex:0 0 auto;width:210px;margin:0;scroll-snap-align:center;text-align:center}
.shots img{width:100%;height:auto;border-radius:22px;box-shadow:0 10px 26px rgba(10,30,80,.28);border:1px solid var(--line);background:var(--card);transition:transform .25s}
.shots figure:hover img{transform:translateY(-6px)}.shots figcaption{font-size:.86rem;color:var(--muted);margin-top:8px;font-weight:700}
.pat{width:100%;border-collapse:collapse;background:var(--card);border-radius:14px;overflow:hidden;box-shadow:var(--shadow)}
.pat th,.pat td{padding:10px 14px;text-align:left;border-bottom:1px solid var(--line)}.pat th{background:rgba(21,75,175,.08);font-weight:700}
.bar{display:block;height:8px;border-radius:6px;background:linear-gradient(90deg,var(--gold),#ff9d00)}
.stage h3{margin:.1em 0 .3em;font-size:1.05rem}
@media (max-width:640px){body{font-size:17px}.shots figure{width:170px}h2{font-size:1.22rem}}

.brand em{font-style:normal}
.opts li{display:flex;gap:8px;align-items:flex-start}.opts li>.bi{flex:1}
html[lang="hi"] .q .bi .L-en,html[lang="en"] .q .bi .L-hi{font-weight:400}
.pat td:last-child{min-width:90px;width:34%}
@media (max-width:560px){.brand em{display:none}.top .in{gap:8px}.nav{gap:6px;flex-wrap:nowrap;margin-left:auto}.lang{padding:4px 10px;font-size:.82rem}.nav a.install{padding:6px 10px;font-size:.82rem;white-space:nowrap}.brand span{font-size:1rem}}
.lt{font-weight:700;color:var(--navy2);white-space:nowrap}

@font-face{font-family:"Lora";font-weight:700;font-display:swap;src:url(/lora-700.woff2) format("woff2"),url(/lora-700.woff) format("woff")}
h1,h2,.brand span,.stat b,.quote{font-family:"Lora","Mukta",Georgia,serif}
.hero h1{color:#FFF1D0;font-weight:700;letter-spacing:0}
.hero p{color:#dfe6f7}.badge{color:var(--gold)}
.top .brand small{font-family:"Mukta",sans-serif}
.cta{color:#0A1633!important}
a{color:var(--navy2)}
@media (prefers-color-scheme:dark){a{color:#8DB0F5}.hero h1{color:#FFF1D0}}
.hero:before,.hero:after{background:rgba(232,186,74,.08)}
/* touch comfort: every tap target is at least 44px, and phones get a bottom navigation bar */
.lang{min-height:44px;min-width:44px}.nav a.install{min-height:44px;display:inline-flex;align-items:center}
.crumbs a{display:inline-block;padding:11px 2px}.crumbs{display:flex;flex-wrap:wrap;align-items:center;gap:0 4px}
footer a{display:inline-block;padding:11px 0}
.links a{display:inline-block;padding:11px 3px}summary{padding:11px 0;cursor:pointer;min-height:44px;display:flex;align-items:center;gap:6px}.nav>a{padding-top:9px;padding-bottom:9px}
.chips a{min-height:44px;display:inline-flex;align-items:center;gap:6px}.chips small{color:var(--muted);font-weight:700}
.bnav{display:none}
@media (max-width:480px){.pat th:last-child,.pat td:last-child{display:none}.pat th,.pat td{padding:9px 7px;font-size:.92rem}.pat{width:100%}}
.xhero{background:linear-gradient(135deg,#0A1633,#17305E);color:#fff;border-radius:20px;padding:20px 22px;margin:8px 0 14px;box-shadow:var(--shadow)}
.xhero h1{color:#FFF1D0;margin:0 0 8px}.xfacts{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 14px}
.xfacts>span{background:rgba(255,255,255,.14);border-radius:999px;padding:5px 14px;font-weight:700;font-size:.92rem}
.xhero .row{display:flex;gap:10px;flex-wrap:wrap}
.sub-h{display:inline-block;padding:8px 0}.card .chips{margin-top:4px}
@media (max-width:700px){
body{padding-bottom:calc(64px + env(safe-area-inset-bottom))}
.bnav{display:flex;position:fixed;left:0;right:0;bottom:0;z-index:30;background:#0A1633;box-shadow:0 -2px 14px rgba(0,0,0,.25);padding-bottom:env(safe-area-inset-bottom)}
.bnav a{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px;min-height:56px;color:#dbe4ff;text-decoration:none;font-size:.74rem;font-weight:700}
.bnav a b{font-size:1.25rem;line-height:1}.bnav a.go{color:#E8BA4A}
}
@media print{.bnav,.top{display:none}}

"""


def esc(s):
    return html.escape(str(s), quote=True)


def fit_title(main, *extras, limit=60):
    """main plus as many of the extras as fit (' | ' separated); search results cut a title at about 60 characters,
    so the words that matter come first and the optional tail is dropped."""
    title = main
    for x in extras:
        if x and len(title) + 3 + len(x) <= limit:
            title += " | " + x
    return title


def cut_desc(text, limit=155):
    """A description under the length search results show, cut at a word boundary."""
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[:limit - 1].rsplit(" ", 1)[0].rstrip(",;:—-· ") + "…"


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
            {"@type": "ListItem", "position": i + 1, "name": name[1] if isinstance(name, tuple) else name,
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
        label = bi(esc(name[0]), esc(name[1])) if isinstance(name, tuple) else esc(name)
        parts.append(f"<a href='{url}'>{label}</a>" if url else f"<span>{label}</span>")
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


LANG_JS = ("<script>document.addEventListener('click',function(ev){var li=ev.target.closest&&ev.target.closest('.opts li');if(!li)return;var ul=li.parentNode;"
           "if(ul.classList.contains('done'))return;ul.classList.add('done');var a=+ul.dataset.a,i=+li.dataset.i;"
           "ul.children[a].classList.add('ok');if(i!==a)li.classList.add('bad');var d=ul.parentNode.querySelector('details');if(d)d.open=true});</script>")


def page(title, desc, body, canonical, base, structured="", og_type="website", title_en=None, desc_en=None):
    ads_head = (f'<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client='
                f'{ADSENSE_CLIENT}" crossorigin="anonymous"></script>') if ADSENSE_CLIENT else ""
    meta = json.dumps({"t": title, "d": desc, "te": title_en or title, "de": desc_en or desc}, ensure_ascii=False).replace("--", "- -")
    return f"""<!--META:{meta}--><!doctype html><html lang="hi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>@@T@@</title><meta name="description" content="@@D@@">
<link rel="canonical" href="@@CANON@@">@@ALT@@
<link rel="icon" href="/favicon-32.png" sizes="32x32">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta property="og:type" content="{og_type}"><meta property="og:site_name" content="{ORG_NAME}">
<meta property="og:title" content="@@T@@"><meta property="og:description" content="@@D@@"><meta property="og:locale" content="@@LOC@@">
<meta property="og:url" content="@@CANON@@">
<meta property="og:image" content="{base}/og-image.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="@@T@@"><meta name="twitter:description" content="@@D@@">
<meta name="twitter:image" content="{base}/og-image.png">
<link rel="preload" href="/lora-700.woff2" as="font" type="font/woff2" crossorigin><link rel="preload" href="/mukta-400.woff2" as="font" type="font/woff2" crossorigin><style>{CSS}</style>{structured}{ads_head}</head><body>
<header class="top"><div class="in"><a class="brand" href="/"><img src="logo-tile-96.webp" width="42" height="42" alt="RailPariksha logo"><span>RailPariksha{bi("<em> · रेलपरीक्षा</em>", "")}<small>{bi("स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए", "By students, for students")}</small></span></a>
<nav class="nav"><a href="/#exams">{bi("परीक्षाएँ", "Exams")}</a><a href="/#papers">{bi("पिछले प्रश्न पत्र", "Papers")}</a><a href="/#subjects">{bi("विषय", "Subjects")}</a><a href="{TELEGRAM_URL}">Telegram</a>@@LANGSWITCH@@<a class="install" href="{APP_PAGE}">{bi("ऐप इंस्टॉल करें", "Install app")}</a></nav></div></header>
<main class="wrap">{body}
<div class="appcta"><strong>{bi("रोज़ मुफ़्त अभ्यास करें!", "Practise free, every day!")}</strong><br>{bi("Daily 10, फ्लैशकार्ड, मॉक टेस्ट, स्ट्रीक और 45,000+ असली PYQ, हिंदी व अंग्रेज़ी में।", "Daily 10, flashcards, mock tests, streaks and 45,000+ real PYQs in Hindi and English.")}<br>
<a class="cta" href="{APP_PAGE}">{bi("Google Play से डाउनलोड करें", "Get it on Google Play")}</a> <a class="btn2" href="{TELEGRAM_URL}">{bi("Telegram चैनल जुड़ें", "Join our Telegram")}</a> <a class="btn2" href="{YOUTUBE_URL}">{bi("YouTube पर देखें", "Watch on YouTube")}</a></div></main>
<footer><div class="cols"><div><h3>RailPariksha</h3>{bi("स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए बनाया गया मुफ़्त अभ्यास ऐप।", "A free practice app made by students, for students.")}</div>
<div><h3>{bi("लिंक", "Links")}</h3><a href="/">{bi("होम", "Home")}</a><br><a href="{APP_PAGE}">Google Play</a><br><a href="{TELEGRAM_URL}">Telegram</a><br><a href="{YOUTUBE_URL}">YouTube</a><br><a href="privacy.html">Privacy Policy</a></div>
<div><h3>{bi("सूचना", "Notice")}</h3>{bi("RailPariksha एक स्वतंत्र शैक्षणिक ऐप है; भारतीय रेलवे, RRB या RPF से संबद्ध नहीं है। आधिकारिक सूचनाएँ आधिकारिक साइट पर देखें।", "RailPariksha is an independent educational app, not affiliated with Indian Railways, RRB or RPF. Check official notices on the official sites.")}<br>{SUPPORT_EMAIL}</div></div>{LANG_JS}</footer>
<nav class="bnav" aria-label="Main"><a href="/"><b>🏠</b>{bi("होम", "Home")}</a><a href="/#exams"><b>🚉</b>{bi("परीक्षाएँ", "Exams")}</a><a href="/#papers"><b>📄</b>{bi("प्रश्न पत्र", "Papers")}</a><a href="/#subjects"><b>📚</b>{bi("विषय", "Subjects")}</a><a class="go" href="{APP_PAGE}"><b>⬇️</b>{bi("ऐप", "App")}</a></nav></body></html>"""


# ---- Two languages, two addresses --------------------------------------------------------------------
# Every page is built once with both languages inline (bi/bib), then written twice: the Hindi page at /x and the
# English page at /en/x. localize() keeps only that page's language in the inline text, fills the head (title,
# description, canonical, hreflang) and points every internal link at the same language.
BI_RE = re.compile(r'<span class="hi">(.*?)</span><span class="en">(.*?)</span>', re.S)
META_RE = re.compile(r"<!--META:(.*?)-->", re.S)
ASSET_EXT = (".png", ".webp", ".woff2", ".woff", ".json", ".xml", ".txt", ".jpg", ".jpeg", ".svg", ".ico")
HREF_RE = re.compile(r"(href|src)=([\"'])([^\"']*)\2")


def page_path(name, clean):
    """/x for x.html (or /x.html without clean URLs); '/' for the home page."""
    if name == "index.html":
        return "/"
    return "/" + (name[:-5] if clean and name.endswith(".html") else name)


def lang_path(path, lang):
    """The address of a root-relative page path in a language ('/' -> '/en/')."""
    if lang == "hi":
        return path
    return "/en/" if path == "/" else "/en" + path


def localize(t, lang, name, base, clean):
    meta = json.loads(META_RE.search(t).group(1))
    t = META_RE.sub("", t, count=1)
    t = BI_RE.sub(lambda m: m.group(1 if lang == "hi" else 2), t)
    t = t.replace("placeholder='खोजें / Search: NTPC 2025, गणित, Group D…'",
                  "placeholder='खोजें: NTPC 2025, गणित, Group D…'" if lang == "hi" else "placeholder='Search: NTPC 2025, Maths, Group D…'")
    if lang == "en":  # absolute page URLs (inside structured data) belong to the English page
        t = re.sub(re.escape(base) + r"/(?!en/)([^\"'<\s]*)",
                   lambda m: m.group(0) if m.group(1).lower().endswith(ASSET_EXT) else base + "/en/" + m.group(1), t)
    title, desc = (meta["t"], meta["d"]) if lang == "hi" else (meta["te"], meta["de"])
    here = lang_path(page_path(name, clean), lang)
    other_lang = "en" if lang == "hi" else "hi"
    hi_url, en_url = base + lang_path(page_path(name, clean), "hi"), base + lang_path(page_path(name, clean), "en")
    alt = (f'<link rel="alternate" hreflang="hi" href="{hi_url}"><link rel="alternate" hreflang="en" href="{en_url}">'
           f'<link rel="alternate" hreflang="x-default" href="{hi_url}">')
    switch = (f'<a class="lang" id="lang" href="{base_less(en_url, base)}" hreflang="en" lang="en">English</a>' if lang == "hi"
              else f'<a class="lang" id="lang" href="{base_less(hi_url, base)}" hreflang="hi" lang="hi">हिंदी</a>')
    t = t.replace('<html lang="hi">', f'<html lang="{lang}">', 1)

    def fix(m):
        attr, q, v = m.group(1), m.group(2), m.group(3)
        if v.startswith(("http:", "https:", "mailto:", "tel:", "#", "data:", "javascript:", "@@")):
            return m.group(0)
        frag = ""
        if "#" in v:
            v, frag = v.split("#", 1)
            frag = "#" + frag
        if v in ("", "/", "index.html", "/index.html"):
            path = "/"
        elif v.endswith(".html"):
            path = ("/" + v.lstrip("/"))
            path = path[:-5] if clean else path
        elif v.lower().endswith(ASSET_EXT):
            return f"{attr}={q}/{v.lstrip('/')}{frag}{q}"
        elif v.startswith("/"):
            path = v
        else:
            return m.group(0)
        if attr == "src":
            return m.group(0)
        return f"{attr}={q}{lang_path(path, lang)}{frag}{q}"

    t = HREF_RE.sub(fix, t)
    t = re.sub(r"""(src)=(["'])(?!/|https?:|data:)([^"']+)\2""", r"\1=\2/\3\2", t)
    t = t.replace("fetch('search.json')", "fetch('/search.json')" if lang == "hi" else "fetch('/search-en.json')")
    if clean:
        t = t.replace("/index.html", "/")
        for q in ('"', "'", "#", "<"):
            t = t.replace(".html" + q, q)
    for tok, val in (("@@T@@", esc(title)), ("@@D@@", esc(desc)), ("@@CANON@@", base + here),
                     ("@@ALT@@", alt), ("@@LOC@@", "hi_IN" if lang == "hi" else "en_IN"), ("@@LANGSWITCH@@", switch)):
        t = t.replace(tok, val)  # last, so none of these URLs is rewritten again
    return t


def base_less(url, base):
    return url[len(base):] if url.startswith(base) else url


def bi(hi, en):
    """Inline text in both languages; the page's language switch shows one and hides the other."""
    return f'<span class="hi">{hi}</span><span class="en">{en}</span>'


def bib(hi, en, cls=""):
    """Block of text in both languages: the chosen language leads, the other follows in a muted tone."""
    if hi.strip() == en.strip():
        return f'<div class="bi {cls}"><div>{hi}</div></div>'
    return f'<div class="bi {cls}"><div class="L-hi">{hi}</div><div class="L-en">{en}</div></div>'


def question_html(q, n):
    opts = "".join(f"<li data-i=\"{i}\"><span class=\"lt\">({bi(LETTERS[i], 'ABCDE'[i])})</span>{bib(esc(o), esc(q['o_en'][i]))}</li>" for i, o in enumerate(q["o_hi"]))
    extra = ""
    if q.get("hook_hi") or q.get("hook_en"):
        extra = "<p>💡 " + bib(esc(q.get("hook_hi") or q.get("hook_en")), esc(q.get("hook_en") or q.get("hook_hi"))) + "</p>"
    right = q["a"]
    return f"""<div class="card"><div class="q">{n}. {bib(esc(q['q_hi']), esc(q['q_en']))}</div>
<ul class="opts" data-a="{q['a']}">{opts}</ul>
<details><summary>{bi('उत्तर व स्पष्टीकरण देखें', 'Show answer and explanation')}</summary>
<p class="ans">{bi('उत्तर', 'Answer')}: ({bi(LETTERS[right], 'ABCDE'[right])}) {bib(esc(q['o_hi'][right]), esc(q['o_en'][right]))}</p>
{bib(esc(q['e_hi']), esc(q['e_en']))}{extra}</details></div>"""


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
    """The site is served by Cloudflare, which answers /x.html with a redirect to /x on workers.dev and on a
    custom domain alike, so links, canonicals and the sitemap always use the extension-less address.
    CLEAN_URLS=0 turns that off (for hosting that serves .html as it is)."""
    return os.environ.get("CLEAN_URLS") != "0"


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

EXAM_STRATEGY = json.loads((CONTENT / "exam_strategy.json").read_text(encoding="utf-8"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="site")
    ap.add_argument("--base-url", default=os.environ.get("SITE_URL", ""))
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    base = (a.base_url or DEFAULT_BASE_URL).rstrip("/")
    if base.split("//")[-1].split("/")[0].endswith(PREVIEW_HOSTS):
        print(f"note: {base} is a preview address; canonical/sitemap/JSON-LD URLs use {DEFAULT_BASE_URL}")
        base = DEFAULT_BASE_URL
    tax = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    qs = []
    for p in sorted((CONTENT / "bank").glob("*.json")):
        qs.extend(json.loads(p.read_text(encoding="utf-8")))
    subjects = {s["id"]: s for s in tax["subjects"]}
    url_meta = []  # (path, priority, changefreq)

    search_index = []      # Hindi pages: [title, path]
    search_index_en = []   # English pages
    clean = clean_urls(base)

    def write(name, content, priority=0.5, changefreq="monthly"):
        meta = json.loads(META_RE.search(content).group(1))
        (out / "en").mkdir(parents=True, exist_ok=True)
        (out / name).write_text(localize(content, "hi", name, base, clean), encoding="utf-8")
        (out / "en" / name).write_text(localize(content, "en", name, base, clean), encoding="utf-8")
        if name not in ("privacy.html", "app.html"):
            path = page_path(name, clean)
            search_index.append([meta["t"].split(" | ")[0], lang_path(path, "hi")])
            search_index_en.append([meta["te"].split(" | ")[0], lang_path(path, "en")])
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
            crumbs = crumbs_html([(("होम", "Home"), "index.html"), ((s["hi"], s["en"]), subj_page), ((t["hi"], t["en"]), None)])
            answer_para = ("<div class='answer'>" + bi(
                f"<strong>{esc(t['hi'])} ({esc(t['en'])})</strong> {n} अभ्यास प्रश्नों का अभ्यास कराता है, प्रत्येक का सही "
                f"उत्तर व हिंदी-अंग्रेज़ी में सरल स्पष्टीकरण सहित। यह {esc(s['hi'])} ({esc(s['en'])}) विषय का हिस्सा है।",
                f"There are {n} practice MCQs for <strong>{esc(t['en'])}</strong> here, each with the correct answer and a "
                f"bilingual explanation. Part of {esc(s['en'])}.") + "</div>")
            related = f"<p class='links muted'>{bi('विषय', 'Subject')}: <a href='{subj_page}'>{bi(esc(s['hi']), esc(s['en']))}</a></p>"
            faq_pairs = [
                (f"How many practice questions are available for {t['en']}?",
                 f"RailPariksha currently has {n} {t['en']} practice questions with answers and explanations, "
                 f"part of the {s['en']} subject."),
                (f"{t['hi']} के कितने अभ्यास प्रश्न उपलब्ध हैं?",
                 f"RailPariksha पर {t['hi']} के {n} अभ्यास प्रश्न उपलब्ध हैं, सही उत्तर व स्पष्टीकरण सहित।"),
            ]
            structured = json_ld(
                breadcrumb_ld(base, [(("होम", "Home"), "index.html"), ((s["hi"], s["en"]), subj_page), ((t["hi"], t["en"]), None)]),
                quiz_ld(f"{t['en']} — {s['en']} Quiz", url, items),
                faq_ld(faq_pairs),
            )
            body = (crumbs + "<h1>" + bi(f"{esc(t['hi'])} — {esc(s['hi'])} अभ्यास प्रश्न", f"{esc(t['en'])} — {esc(s['en'])} practice questions") + "</h1>"
                    f"<p class='muted'>" + bi(f"{esc(t['en'])} · {esc(s['en'])} MCQ उत्तर व स्पष्टीकरण सहित · {n} प्रश्न",
                                            f"{esc(t['en'])} · {esc(s['en'])} MCQs with answers and explanations · {n} questions") + "</p>" + answer_para + related +
                    "".join(question_html(q, i + 1) for i, q in enumerate(items)))
            write(name, page(fit_title(f"{t['hi']} अभ्यास प्रश्न उत्तर सहित", s['hi'], ORG_NAME, limit=70),
                             cut_desc(f"{t['hi']} पर {n} अभ्यास प्रश्न, सही उत्तर व सरल स्पष्टीकरण। {s['hi']} ({s['en']}) · RRB व RPF परीक्षा।"),
                             body, url, base, structured,
                             title_en=fit_title(f"{t['en']} MCQs with Answers", s['en'], ORG_NAME, limit=70),
                             desc_en=cut_desc(f"{n} {t['en']} practice MCQs with correct answers and simple explanations in English and Hindi. {s['en']} for RRB and RPF exams.")),
                  priority=0.5, changefreq="monthly")

    # ---- Subject pages -------------------------------------------------
    exams_by_subject = {}
    for e in tax["exams"]:
        for entry in e["subjects"]:
            exams_by_subject.setdefault(entry["id"], []).append((e, entry["w"]))

    for s in tax["subjects"]:
        topic_links = [f"<a href='{topic_pages[(s['id'], t['id'])]}'>{bi(esc(t['hi']), esc(t['en']))} <small>{topic_counts[(s['id'], t['id'])]}</small></a>"
                       for t in s["topics"] if (s["id"], t["id"]) in topic_pages]
        if not topic_links:
            continue
        exam_links = [f"<a href='exam-{e['id']}.html'>{bi(esc(e['hi']), esc(e['en']))} <small>{w}%</small></a>"
                      for e, w in exams_by_subject.get(s["id"], [])]
        name = f"subject-{s['id']}.html"
        total_qs = sum(topic_counts[(s["id"], t["id"])] for t in s["topics"] if (s["id"], t["id"]) in topic_counts)
        url = f"{base}/{name}"
        crumbs = crumbs_html([(("होम", "Home"), "index.html"), ((s["hi"], s["en"]), None)])
        in_hi = ", ".join(esc(e['hi']) for e, _ in exams_by_subject.get(s['id'], [])) or "कई परीक्षाओं"
        in_en = ", ".join(esc(e['en']) for e, _ in exams_by_subject.get(s['id'], [])) or "several exams"
        answer_para = ("<div class='answer'>" + bi(
            f"{esc(s['hi'])} ({esc(s['en'])}) में {len(topic_links)} टॉपिक और कुल {total_qs} अभ्यास प्रश्न हैं। "
            f"यह विषय {in_hi} में पूछा जाता है।",
            f"{esc(s['en'])} covers {len(topic_links)} topics with {total_qs} practice questions on RailPariksha, "
            f"and appears in {in_en}.") + "</div>")
        structured = json_ld(
            breadcrumb_ld(base, [(("होम", "Home"), "index.html"), ((s["hi"], s["en"]), None)]),
            {
                "@context": "https://schema.org", "@type": "ItemList", "name": f"{s['en']} topics",
                "itemListElement": [
                    {"@type": "ListItem", "position": i + 1, "name": t["en"],
                     "url": f"{base}/{topic_pages[(s['id'], t['id'])]}"}
                    for i, t in enumerate(s["topics"]) if (s["id"], t["id"]) in topic_pages
                ],
            },
        )
        shero = (f"<section class='xhero'><h1>{bi(esc(s['hi']) + ' (' + esc(s['en']) + ') अभ्यास प्रश्न', esc(s['en']) + ' practice questions')}</h1>"
                 f"<div class='xfacts'><span>{len(topic_links)} {bi('टॉपिक', 'topics')}</span><span>{total_qs:,} {bi('प्रश्न', 'questions')}</span></div>"
                 f"<div class='row'><a class='cta' href='{APP_PAGE}'>{bi('ऐप में मुफ़्त अभ्यास करें', 'Practise free in the app')}</a></div></section>")
        body = (crumbs + shero + answer_para +
                f"<h2>{bi('टॉपिक चुनें', 'Choose a topic')}</h2><div class='chips'>{''.join(topic_links)}</div>" +
                (f"<h2>{bi('यह विषय इन परीक्षाओं में आता है', 'Appears in these exams')}</h2>"
                 f"<div class='chips'>{''.join(exam_links)}</div>" if exam_links else ""))
        write(name, page(fit_title(f"{s['hi']} अभ्यास प्रश्न", "सभी टॉपिक", ORG_NAME, limit=62),
                         cut_desc(f"{s['hi']} ({s['en']}) के {len(topic_links)} टॉपिक और {total_qs} अभ्यास प्रश्न, उत्तर व स्पष्टीकरण सहित।"),
                         body, url, base, structured,
                         title_en=fit_title(f"{s['en']} Practice Questions", "All Topics", ORG_NAME, limit=62),
                         desc_en=cut_desc(f"{total_qs:,} {s['en']} practice questions across {len(topic_links)} topics for RRB and RPF exams, with answers and explanations in English and Hindi.")),
              priority=0.7, changefreq="weekly")

    # ---- Exam pages ------------------------------------------------
    exam_cards = []
    for e in tax["exams"]:
        subj_links = []
        for entry in e["subjects"]:
            sid, w = entry["id"], entry["w"]
            s = subjects.get(sid)
            if not s:
                continue
            tl = [f"<a href='{topic_pages[(sid, t['id'])]}'>{bi(esc(t['hi']), esc(t['en']))} <small>{topic_counts[(sid, t['id'])]}</small></a>"
                  for t in s["topics"] if (sid, t["id"]) in topic_counts]
            if tl:
                subj_links.append(
                    f"<div class='card'><a class='sub-h' href='subject-{sid}.html'><strong>{bi(esc(s['hi']) + ' · ' + esc(s['en']), esc(s['en']))} ({w}%)</strong></a><div class='chips'>{''.join(tl)}</div></div>")
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
        answer_para = ("<div class='answer'>" + bi(
            f"<strong>{esc(e['hi'])} ({esc(e['en'])})</strong> में विषयवार भारांश (weightage) इस प्रकार है — "
            f"{esc(weight_bits_hi)} — और नकारात्मक अंकन: {negtxt}।",
            f"<strong>{esc(e['en'])}</strong> covers {esc(weight_bits_en)}, with {neg_en}.") + "</div>")
        crumbs = crumbs_html([(("होम", "Home"), "index.html"), ((e["hi"], e["en"]), None)])
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
            breadcrumb_ld(base, [(("होम", "Home"), "index.html"), ((e["hi"], e["en"]), None)]),
            course_ld(e, url, subjects, base),
            faq_ld(faq_pairs),
        )
        strat = EXAM_STRATEGY.get(e["id"], {})
        pq, pm = e.get("paper_q"), e.get("paper_min")
        pattern = ""
        if pq and pm:
            rows = "".join(
                f"<tr><td>{bi(esc(subjects[en_['id']]['hi']), esc(subjects[en_['id']]['en']))}</td><td>{en_['w']}%</td>"
                f"<td>~{round(pq * en_['w'] / 100)}</td><td><span class='bar' style='width:{en_['w'] * 2}%'></span></td></tr>"
                for en_ in e["subjects"] if en_["id"] in subjects)
            pattern = (
                f"<h2>{bi('परीक्षा पैटर्न', 'Exam pattern')}</h2>"
                f"<table class='pat'><tr><th>{bi('विषय', 'Subject')}</th><th>{bi('भारांश', 'Weight')}</th><th>{bi('लगभग प्रश्न', 'Approx. questions')}</th><th></th></tr>{rows}</table>"
                f"<p class='muted'>{bi('प्रश्नों की संख्या भारांश से निकाला गया अनुमान है; आधिकारिक अधिसूचना में अंतिम पैटर्न देखें।', 'Question counts are an estimate from the weightage; check the official notification for the final pattern.')}</p>")
        stages = ""
        if strat.get("stages"):
            cards = "".join(
                f"<div class='card stage'><h3>{bi(esc(st['hi']), esc(st['en']))}</h3>"
                f"{bi(esc(st.get('detail_hi', '')), esc(st.get('detail_en', '')))}</div>"
                for st in strat["stages"])
            stages = f"<h2>{bi('चयन के चरण', 'Selection stages')}</h2>{cards}"
        facts = ""
        if pq and pm:
            facts = (f"<div class='xfacts'><span>{pq} {bi('प्रश्न', 'questions')}</span><span>{pm} {bi('मिनट', 'minutes')}</span>"
                     f"<span>{bi('नेगेटिव', 'Negative')} {neg_fraction(neg) if neg else '0'}</span></div>")
        hero = (f"<section class='xhero'><h1>{bi(esc(e['hi']) + ' अभ्यास प्रश्न ' + str(date.today().year), esc(e['en']) + ' practice questions ' + str(date.today().year))}</h1>{facts}"
                f"<div class='row'><a class='cta' href='{APP_PAGE}'>{bi('ऐप में मुफ़्त अभ्यास करें', 'Practise free in the app')}</a>"
                f"<a class='btn2' href='#practice'>{bi('विषयवार अभ्यास', 'Practise by subject')}</a></div></section>")
        body = (crumbs + hero + answer_para + pattern + stages +
                f"<h2 id='practice'>{bi('विषयवार अभ्यास', 'Practise by subject')}</h2>" + "".join(subj_links))
        write(name, page(fit_title(f"{e['hi']} अभ्यास प्रश्न {date.today().year}", ORG_NAME, limit=62),
                         f"{e['hi']} ({e['en']}) के लिए विषयवार अभ्यास प्रश्न, उत्तर व स्पष्टीकरण। {ORG_NAME} ऐप पर मुफ़्त मॉक टेस्ट।",
                         body, url, base, structured,
                         title_en=fit_title(f"{e['en']} Practice Questions {date.today().year}", "Free MCQs", ORG_NAME, limit=62),
                         desc_en=cut_desc(f"Free {e['en']} practice questions by subject, with answers and explanations in English and Hindi. Syllabus weightage, exam pattern and mock tests.")),
              priority=0.9, changefreq="weekly")
        exam_cards.append(f"<a class='card tile' href='{name}'><span class='ic'>{EXAM_ICONS.get(e['id'], '📘')}</span><strong>{bib(esc(e['hi']), esc(e['en']))}</strong></a>")

    # ---- Previous-year papers ---------------------------------------
    import site_pyq
    pyq_cards = site_pyq.add_pyq_pages(
        dict(page=page, esc=esc, question_html=question_html, bi=bi, bib=bib, crumbs_html=crumbs_html, json_ld=json_ld,
             breadcrumb_ld=breadcrumb_ld, faq_ld=faq_ld, ad_unit=ad_unit, ORG_NAME=ORG_NAME, fit_title=fit_title, cut_desc=cut_desc),
        tax, CONTENT, base, write)

    # ---- Home ------------------------------------------------------
    subject_cards = [f"<a class='card' href='subject-{s['id']}.html'><strong>{bib(esc(s['hi']), esc(s['en']))}</strong></a>"
                     for s in tax["subjects"] if any((s["id"], t["id"]) in topic_pages for t in s["topics"])]
    home_url = f"{base}/index.html"
    answer_para = ("<div class='answer'>" + bi(
        "RailPariksha, भारतीय रेलवे (RRB) व RPF भर्ती परीक्षाओं — जैसे RRB NTPC, ग्रुप डी, ALP, JE, पैरामेडिकल, RPF कांस्टेबल "
        "व सब-इंस्पेक्टर — के लिए विषयवार व टॉपिकवार अभ्यास प्रश्न, सही उत्तर और सरल हिंदी-अंग्रेज़ी स्पष्टीकरण मुफ़्त में उपलब्ध कराता है।",
        "RailPariksha offers free, subject-wise and topic-wise practice MCQs with answers and bilingual explanations for every "
        "major RRB and RPF exam: NTPC, Group D, ALP, JE, Paramedical, RPF Constable and Sub-Inspector.") + "</div>")
    structured = json_ld(
        {"@context": "https://schema.org", "@type": "Organization", "name": ORG_NAME,
         "url": home_url, "logo": f"{base}/logo-tile-460.webp", "sameAs": [TELEGRAM_URL, YOUTUBE_URL] + ([PLAY_URL] if links.APP_LIVE else [])},
        {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": ORG_NAME,
         "operatingSystem": "Android", "applicationCategory": "EducationApplication", **({"installUrl": PLAY_URL} if links.APP_LIVE else {}),
         "inLanguage": ["hi", "en"], "offers": {"@type": "Offer", "price": "0", "priceCurrency": "INR"}},
        {"@context": "https://schema.org", "@type": "WebSite", "name": ORG_NAME, "url": home_url},
    )
    total_pyq = sum(len(v) for sub in site_pyq.load(CONTENT).values() for paper in sub.values() for v in paper.values())
    n_papers = sum(len(sub) for sub in site_pyq.load(CONTENT).values())
    subject_chips = "".join(f"<a href='subject-{s2['id']}.html'>{SUBJECT_ICONS.get(s2['id'], '📘')} {bi(esc(s2['hi']), esc(s2['en']))}</a>"
                            for s2 in tax["subjects"] if any((s2["id"], t["id"]) in topic_pages for t in s2["topics"]))
    mot = json.loads((CONTENT / "motivation" / "motivation.json").read_text(encoding="utf-8"))
    mot = [m for m in mot if m.get("hi") and m.get("en")]
    mot_today = mot[date.today().toordinal() % len(mot)]
    n_cards = sum(len(json.loads(f.read_text(encoding="utf-8"))) for f in (CONTENT / "flashcards").glob("*.json"))
    n_sheets = sum(len(json.loads(f.read_text(encoding="utf-8"))) for f in (CONTENT / "cheat_sheets").glob("*.json"))
    n_mcq = len(qs)
    features = [
        ("🎯", "Daily 10", "Daily 10", "हर दिन आपकी कमज़ोर जगहों से 10 प्रश्न", "Ten questions a day from your weak spots"),
        ("🗂️", f"{n_cards:,} फ्लैशकार्ड", f"{n_cards:,} flashcards", "भूलने से पहले याद कराने वाला स्मार्ट रिवीज़न", "Smart revision that reminds you before you forget"),
        ("📝", "मॉक टेस्ट", "Mock tests", "टाइमर, पैलेट और असली नेगेटिव मार्किंग के साथ", "With a timer, question palette and real negative marking"),
        ("📕", "मिस्टेक बुक", "Mistake book", "हर गलत उत्तर तब तक लौटता है जब तक आप सीख न लें", "Every wrong answer comes back until you master it"),
        ("📰", "रोज़ का करेंट अफेयर्स", "Daily current affairs", "सुबह की डाइजेस्ट और क्विज़", "A morning digest and a quiz"),
        ("🧾", f"{n_sheets} चीट शीट", f"{n_sheets} cheat sheets", "फ़ॉर्मूले और फ़ैक्ट एक नज़र में", "Formulas and facts at a glance"),
        ("🔥", "स्ट्रीक और लेवल", "Streaks and levels", "रोज़ पढ़ाई की आदत, जनरल से राजधानी तक", "A daily study habit, from General to Rajdhani"),
        ("🏆", "लीडरबोर्ड", "Leaderboard", "अपनी परीक्षा के दूसरे उम्मीदवारों से रैंक की तुलना", "Compare your rank with other candidates of your exam"),
        ("⚡", "60-सेकंड स्पीड राउंड", "60-second speed round", "प्लेटफ़ॉर्म पर इंतज़ार के पलों के लिए", "For the minutes you wait on a platform"),
        ("📶", "ऑफलाइन भी", "Works offline", "एक बार डाउनलोड, फिर बिना इंटरनेट", "Download once, then no internet needed"),
        ("🌐", "हिंदी ⇄ English", "Hindi ⇄ English", "हर प्रश्न, विकल्प और व्याख्या दोनों भाषा में", "Every question, option and explanation in both languages"),
        ("💪", "रोज़ की प्रेरणा", "Daily motivation", f"{len(mot)}+ कोट्स और स्टडी टिप्स", f"{len(mot)}+ quotes and study tips"),
    ]
    feature_cards = "".join(f"<div class='card feat'><span class='ic'>{i}</span><b>{bi(esc(th), esc(te))}</b><br><span class='muted'>{bi(esc(dh), esc(de))}</span></div>"
                            for i, th, te, dh, de in features)
    mot_json = json.dumps([[m["hi"], m["en"]] for m in mot], ensure_ascii=False).replace("</", "<\\/")
    motivation_block = (
        f"<h2>{bi('आज की प्रेरणा', 'Today’s motivation')}</h2>"
        f"<div class='card quote rv'><div class='bi'><div class='L-hi' id='mhi'>{esc(mot_today['hi'])}</div><div class='L-en' id='men'>{esc(mot_today['en'])}</div></div>"
        f"<a class='cta' id='mwa' href='#'>{bi('WhatsApp पर शेयर करें', 'Share on WhatsApp')}</a></div>"
        f"<script>(function(){{var m={mot_json},d=Math.floor(Date.now()/864e5)%m.length,x=m[d];"
        "document.getElementById('mhi').textContent=x[0];document.getElementById('men').textContent=x[1];"
        "var w=document.getElementById('mwa');w.addEventListener('click',function(){var en=document.documentElement.lang==='en';"
        "w.href='https://wa.me/?text='+encodeURIComponent((en?x[1]:x[0])+'\\n\\n'+location.origin+'/')});})();</script>"
        f"<h2>{bi('ऐप में क्या-क्या है', 'What’s inside the app')}</h2>"
        f"<div class='grid feats rv'>{feature_cards}</div>")
    import telegram_bot as tb
    web_pool = {}
    for sid in ("maths", "reasoning", "gk", "science", "computer"):
        pool = [r for r in tb.load_pyq(sid) if r.get("q_en") and len(r.get("o_en", [])) == len(r["o_hi"]) and r.get("e_en")
                and len(r["q_hi"]) <= 220 and all(len(o) <= 70 for o in r["o_hi"]) and len(r["e_hi"]) <= 380]
        pick = tb.pick(pool, "web-" + sid, date.today())
        if pick:
            web_pool[sid] = pick
    try_data = json.dumps([
        {"s": [subjects[k]["hi"], subjects[k]["en"]] if k in subjects else [k, k], "x": tb.exam_label(r.get("pyq")),
         "q": [r["q_hi"], r["q_en"]], "o": [[a, b] for a, b in zip(r["o_hi"], r["o_en"])], "a": r["a"],
         "e": [r["e_hi"], r["e_en"]]} for k, r in web_pool.items()], ensure_ascii=False).replace("</", "<\\/")
    shot_caps = [("आज का मिशन", "Today’s mission"), ("पिछले साल के प्रश्न", "Previous year papers"),
                 ("व्याख्या सहित उत्तर", "Answers with explanations"), ("रोज़ का करेंट अफेयर्स", "Daily current affairs"),
                 ("स्मार्ट फ्लैशकार्ड", "Smart flashcards"), ("पूरा मॉक टेस्ट", "Full mock tests"),
                 ("विषयवार अभ्यास", "Practice by subject")]
    shots_html = "".join(
        f"<figure><img loading='lazy' src='shot-{i}.webp' width='360' height='640' alt='RailPariksha app: {esc(en_)}'>"
        f"<figcaption>{bi(esc(hi_), esc(en_))}</figcaption></figure>" for i, (hi_, en_) in enumerate(shot_caps, 1))
    try_block = (
        f"<h2>{bi('एक प्रश्न आज़माइए', 'Try a real question')}</h2>"
        "<div class='try rv' id='try'><div class='meta'><span id='tm'></span><span id='tc'></span></div>"
        "<div class='qq' id='tq'></div><div id='to'></div>"
        "<div class='res' id='tr'><div id='te'></div><div class='row2'><button type='button' id='tn'>"
        + bi('अगला प्रश्न →', 'Next question →') + "</button><a class='cta' href='" + APP_PAGE + "'>"
        + bi('ऐप में और अभ्यास करें', 'Practise more in the app') + "</a></div></div></div>"
        "<script>(function(){var D=" + try_data + ",i=0,el=function(id){return document.getElementById(id)},"
        "L=function(){return document.documentElement.lang==='en'?1:0};"
        "function bi(a){var s=document.createElement('span'),h=document.createElement('span'),e=document.createElement('span');"
        "h.className='hi';e.className='en';h.textContent=a[0];e.textContent=a[1];s.appendChild(h);s.appendChild(e);return s}"
        "function show(){if(!D.length)return;var d=D[i%D.length],t=el('try');t.classList.remove('done');"
        "el('tm').innerHTML='';el('tm').appendChild(bi(d.s));el('tc').textContent=d.x+'  ·  '+(i%D.length+1)+'/'+D.length;"
        "el('tq').innerHTML='';el('tq').appendChild(bi(d.q));var o=el('to');o.innerHTML='';"
        "d.o.forEach(function(x,k){var b=document.createElement('button');b.type='button';b.className='opt';b.appendChild(bi(x));"
        "b.addEventListener('click',function(){if(t.classList.contains('done'))return;t.classList.add('done');"
        "o.children[d.a].classList.add('ok');if(k!==d.a)b.classList.add('bad');el('te').innerHTML='';el('te').appendChild(bi(d.e))});o.appendChild(b)})}"
        "el('tn').addEventListener('click',function(){i++;show()});show()})();</script>")
    shots_block = f"<h2>{bi('ऐप एक नज़र में', 'The app at a glance')}</h2><div class='shots rv'>{shots_html}</div>"
    tick_html = "<div class='tick'><div>🚉 RRB NTPC &nbsp;•&nbsp; 🛤️ Group D &nbsp;•&nbsp; 🚂 ALP &nbsp;•&nbsp; 🔧 Technician &nbsp;•&nbsp; 🏗️ JE &nbsp;•&nbsp; 🩺 Paramedical &nbsp;•&nbsp; 🛡️ RPF Constable &nbsp;•&nbsp; 🎖️ RPF SI &nbsp;•&nbsp; 📦 DFCCIL &nbsp;•&nbsp; मुफ़्त · हिंदी + English &nbsp;•&nbsp; 🚉 RRB NTPC &nbsp;•&nbsp; 🛤️ Group D &nbsp;•&nbsp; 🚂 ALP &nbsp;•&nbsp; 🔧 Technician &nbsp;•&nbsp; 🏗️ JE &nbsp;•&nbsp; 🩺 Paramedical &nbsp;•&nbsp; 🛡️ RPF Constable &nbsp;•&nbsp; 🎖️ RPF SI &nbsp;•&nbsp; 📦 DFCCIL &nbsp;•&nbsp; मुफ़्त · हिंदी + English</div></div>".replace("मुफ़्त · हिंदी + English", bi("मुफ़्त · हिंदी + English", "Free · Hindi + English"))
    body = (
        "<section class='hero'><div class='txt'><span class='badge'>" + bi('स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए', 'By students, for students') + " 🤝</span>"
        "<h1>" + bi('रेलवे परीक्षा की तैयारी, बिल्कुल मुफ़्त', 'Railway exam preparation, completely free') + "</h1>"
        "<p>" + bi('RRB NTPC, ग्रुप D, ALP, JE, RPF के असली पिछले साल के प्रश्न, सही उत्तर और सरल हिंदी-अंग्रेज़ी व्याख्या के साथ।',
                   'Real previous-year questions for RRB NTPC, Group D, ALP, JE and RPF, with answers and simple Hindi and English explanations.') + "</p>"
        f"<div class='row'><a class='cta pulse' href='{APP_PAGE}'>{bi('ऐप डाउनलोड करें', 'Download the app')}</a><a class='btn2' href='{TELEGRAM_URL}'>{bi('Telegram चैनल', 'Telegram channel')}</a><a class='btn2' href='{YOUTUBE_URL}'>{bi('YouTube चैनल', 'YouTube channel')}</a></div>"
        f"<div class='trust'><span>✓ {bi('मुफ़्त', 'Free')}</span><span>✓ {bi('बिना साइन-अप', 'No sign-up')}</span><span>✓ {bi('ऑफलाइन भी', 'Works offline')}</span><span>✓ {bi('हिंदी + English', 'Hindi + English')}</span></div></div>"
        "<span class='glow'></span><img class='logo' src='logo-tile-460.webp' width='230' height='230' alt='RailPariksha logo' fetchpriority='high'>"
        '<div class="track"><svg class="train" viewBox="0 0 210 58" aria-hidden="true"><g><rect x="4" y="8" width="150" height="36" rx="8" fill="#fff"/><path d="M154 8h20q24 2 32 26v10h-52z" fill="#f4f8ff"/><rect x="4" y="28" width="202" height="6" fill="#E8BA4A"/><rect x="16" y="14" width="22" height="12" rx="3" fill="#0A1633"/><rect x="46" y="14" width="22" height="12" rx="3" fill="#0A1633"/><rect x="76" y="14" width="22" height="12" rx="3" fill="#0A1633"/><rect x="106" y="14" width="22" height="12" rx="3" fill="#0A1633"/><path d="M160 14h14q14 2 20 14h-34z" fill="#0A1633"/><circle cx="203" cy="38" r="3" fill="#F3D27C"/><circle cx="36" cy="48" r="6" fill="#16203a"/><circle cx="80" cy="48" r="6" fill="#16203a"/><circle cx="130" cy="48" r="6" fill="#16203a"/><circle cx="176" cy="48" r="6" fill="#16203a"/></g></svg><div class="rails"></div></div></section>'
        f"{tick_html}"
        f"<div class='stats rv'><div class='stat'><b data-count='{total_pyq}'>{total_pyq:,}</b><span>{bi('असली PYQ प्रश्न', 'real PYQ questions')}</span></div>"
        f"<div class='stat'><b data-count='{n_papers}'>{n_papers}</b><span>{bi('पिछले प्रश्न पत्र', 'past papers')}</span></div>"
        f"<div class='stat'><b data-count='{len(tax['exams'])}'>{len(tax['exams'])}</b><span>{bi('परीक्षाएँ', 'exams')}</span></div>"
        f"<div class='stat'><b>{bi('हिंदी + EN', 'Hindi + EN')}</b><span>{bi('हर प्रश्न दोनों भाषा में', 'every question in both')}</span></div></div>"
        "<div class='search'><input id='q' type='search' placeholder='खोजें / Search: NTPC 2025, गणित, Group D…' autocomplete='off' aria-label='Search'><div id='hits' hidden></div></div>"
        f"<h2 id='exams'>{bi('आप किस परीक्षा की तैयारी कर रहे हैं?', 'Which exam are you preparing for?')}</h2>"
        f"<div class='grid rv'>{''.join(exam_cards)}</div>"
        + try_block + shots_block +
        f"<h2 id='papers'>{bi('पिछले साल के प्रश्न पत्र', 'Previous year papers')}</h2>"
        f"<div class='grid rv'>{pyq_cards}</div>"
        f"<h2 id='subjects'>{bi('विषय के अनुसार अभ्यास', 'Practise by subject')}</h2>"
        f"<div class='chips rv'>{subject_chips}</div>"
        + motivation_block +
        f"<h2>{bi('कैसे काम करता है', 'How it works')}</h2><div class='steps rv'>"
        f"<div class='card'><b>{bi('1. परीक्षा चुनें', '1. Pick your exam')}</b><br>{bi('अपनी परीक्षा चुनें और उसका सिलेबस व पैटर्न देखें।', 'Choose your exam and see its syllabus and pattern.')}</div>"
        f"<div class='card'><b>{bi('2. रोज़ अभ्यास करें', '2. Practise daily')}</b><br>{bi('Daily 10, टॉपिक टेस्ट और असली PYQ, व्याख्या के साथ।', 'Daily 10, topic tests and real PYQs, with explanations.')}</div>"
        f"<div class='card'><b>{bi('3. मॉक टेस्ट दें', '3. Take mock tests')}</b><br>{bi('ऐप में टाइमर और सही नेगेटिव मार्किंग के साथ पूरा मॉक।', 'Full mocks in the app, with a timer and correct negative marking.')}</div></div>"
        + answer_para)
    search_js = ("<script>(function(){var i=document.getElementById('q'),h=document.getElementById('hits'),d=null;"
                 "function load(c){if(d)return c();fetch('search.json').then(function(r){return r.json()}).then(function(j){d=j;c()})}"
                 "i.addEventListener('input',function(){var t=i.value.trim().toLowerCase();if(t.length<2){h.hidden=true;return}"
                 "load(function(){var w=t.split(/\\s+/),o=[];for(var k=0;k<d.length&&o.length<12;k++){var s=d[k][0].toLowerCase(),m=true;"
                 "for(var x=0;x<w.length;x++){if(s.indexOf(w[x])<0){m=false;break}}if(m)o.push(d[k])}"
                 "h.innerHTML=o.length?o.map(function(e){return '<a href=\"'+e[1]+'\">'+e[0]+'</a>'}).join(''):'<a>कुछ नहीं मिला / Nothing found</a>';h.hidden=false})})})();</script>")
    body += search_js
    motion_js = ("<script>(function(){var t=document.querySelector('.top'),on=function(){t&&t.classList.toggle('sm',window.scrollY>40)};"
                 "window.addEventListener('scroll',on,{passive:true});on();"
                 "var els=document.querySelectorAll('.rv');if(!('IntersectionObserver' in window)){els.forEach(function(e){e.classList.add('in')})}else{"
                 "var io=new IntersectionObserver(function(es){es.forEach(function(e){if(e.isIntersecting){e.target.classList.add('in');io.unobserve(e.target)}})},{threshold:.12});"
                 "els.forEach(function(e){io.observe(e)})}"
                 "document.querySelectorAll('[data-count]').forEach(function(b){var n=+b.dataset.count,s=null;if(window.matchMedia('(prefers-reduced-motion: reduce)').matches)return;"
                 "var o=new IntersectionObserver(function(es){if(!es[0].isIntersecting)return;o.disconnect();function f(ts){s=s||ts;var p=Math.min((ts-s)/1400,1),v=Math.floor(n*(1-Math.pow(1-p,3)));"
                 "b.textContent=v.toLocaleString('en-IN');if(p<1)requestAnimationFrame(f);else b.textContent=n.toLocaleString('en-IN')}requestAnimationFrame(f)});o.observe(b)})})();</script>")
    body += motion_js
    write("index.html", page(f"{ORG_NAME} — RRB NTPC, ग्रुप डी, RPF अभ्यास प्रश्न हिंदी में",
                             "RRB NTPC, Group D, ALP, JE, RPF Constable & SI practice questions in Hindi with answers & explanations. Free daily quiz, flashcards and mock tests.",
                             body, home_url, base, structured,
                             title_en=f"{ORG_NAME} — Free RRB NTPC, Group D, ALP, JE & RPF Practice Questions",
                             desc_en="Free RRB NTPC, Group D, ALP, JE and RPF previous-year questions and practice MCQs with answers and explanations in English and Hindi. Daily quiz, mock tests."),
          priority=1.0, changefreq="weekly")

    privacy_url = f"{base}/privacy.html"
    privacy = f"""{crumbs_html([(("होम", "Home"), "index.html"), (("गोपनीयता नीति", "Privacy Policy"), None)])}<h1>Privacy Policy · गोपनीयता नीति</h1><p class="muted">Last updated: {date.today().isoformat()}</p>
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

    # /app: the one address every video, post and button uses for the app. Not live: "coming soon" with Telegram and
    # YouTube. Live (links.APP_LIVE): sends the visitor to the Play listing (also as a redirect in `_redirects`).
    app_url = f"{base}/app"
    if links.APP_LIVE:
        app_body = (f"<meta http-equiv='refresh' content='0; url={PLAY_URL}'>"
                    f"<section class='xhero'><h1>{bi('Google Play खुल रहा है…', 'Opening Google Play…')}</h1>"
                    f"<div class='row'><a class='cta' href='{PLAY_URL}'>{bi('Google Play पर खोलें', 'Open on Google Play')}</a></div></section>")
    else:
        app_body = (f"<section class='xhero'><h1>{bi('RailPariksha ऐप जल्द Google Play पर', 'The RailPariksha app is coming to Google Play')}</h1>"
                    f"<p>{bi('मुफ़्त RRB / RPF तैयारी: पिछले साल के प्रश्न, रोज़ का क्विज़ और मॉक टेस्ट, हिंदी और English में। लॉन्च की ख़बर सबसे पहले पाने के लिए Telegram से जुड़ें। रोज़ के क्विज़ वहीं मिलते हैं।', 'Free RRB / RPF preparation: previous-year questions, daily quizzes and mock tests in Hindi and English. Join our Telegram to hear first when it launches; the daily quizzes are there already.')}</p>"
                    f"<h2>{bi('तब तक यहाँ अभ्यास करें', 'Meanwhile, practise here')}</h2>"
                    f"<div class='row'><a class='cta' href='{TELEGRAM_URL}'>{bi('Telegram चैनल जुड़ें', 'Join our Telegram')}</a>"
                    f"<a class='btn2' href='{YOUTUBE_URL}'>{bi('YouTube पर देखें', 'Watch on YouTube')}</a>"
                    f"<a class='btn2' href='index.html'>{bi('वेबसाइट पर अभ्यास करें', 'Practise on the website')}</a></div></section>")
    write("app.html", page(f"{ORG_NAME} App | {ORG_NAME}", "Get the RailPariksha app", app_body, app_url, base,
                           title_en=f"{ORG_NAME} App | {ORG_NAME}", desc_en="Get the RailPariksha app"),
          priority=0.3, changefreq="monthly")
    url_meta.pop()  # a utility page, not for search results

    assets_src = ROOT / "docs/store/site_assets"
    if assets_src.exists():
        for f in assets_src.iterdir():
            shutil.copy(f, out / f.name)

    # app-ads.txt lets AdMob confirm the app's ads are sold by this developer; it must sit at the site root.
    (out / "app-ads.txt").write_text("google.com, pub-9100209280220037, DIRECT, f08c47fec0942fa0\n", encoding="utf-8")
    # Security and caching headers for Cloudflare's static assets (`_headers` is read by the platform, not served).
    (out / "_headers").write_text(
        "/*\n"
        "  X-Content-Type-Options: nosniff\n"
        "  Referrer-Policy: strict-origin-when-cross-origin\n"
        "  X-Frame-Options: SAMEORIGIN\n"
        "  Permissions-Policy: camera=(), microphone=(), geolocation=()\n"
        "  Strict-Transport-Security: max-age=31536000\n"
        "/*.woff2\n"
        "  Cache-Control: public, max-age=31536000, immutable\n"
        "/*.webp\n"
        "  Cache-Control: public, max-age=86400\n"
        "/*.png\n"
        "  Cache-Control: public, max-age=86400\n", encoding="utf-8")
    if links.APP_LIVE:
        (out / "_redirects").write_text(f"/app {PLAY_URL} 302\n/en/app {PLAY_URL} 302\n", encoding="utf-8")
    (out / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {base}/sitemap.xml\n", encoding="utf-8")
    today = date.today().isoformat()
    sitemap_entries = []
    for name, prio, freq in url_meta:
        hi_u = base + lang_path(page_path(name, clean), "hi")
        en_u = base + lang_path(page_path(name, clean), "en")
        alts = (f'<xhtml:link rel="alternate" hreflang="hi" href="{hi_u}"/>'
                f'<xhtml:link rel="alternate" hreflang="en" href="{en_u}"/>'
                f'<xhtml:link rel="alternate" hreflang="x-default" href="{hi_u}"/>')
        for u in (hi_u, en_u):
            sitemap_entries.append(f"<url><loc>{u}</loc><lastmod>{today}</lastmod>"
                                   f"<changefreq>{freq}</changefreq><priority>{prio}</priority>{alts}</url>")
    (out / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">'
        + "".join(sitemap_entries) + "</urlset>\n",
        encoding="utf-8")
    (out / "search.json").write_text(json.dumps(search_index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    (out / "search-en.json").write_text(json.dumps(search_index_en, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"site: {len(url_meta)} pages x 2 languages -> {out}")


if __name__ == "__main__":
    main()
