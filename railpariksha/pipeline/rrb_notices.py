#!/usr/bin/env python3
"""Watches the official Railway Recruitment Board websites for new notice titles.

It never states a date, a vacancy count or an eligibility rule of its own: it only notices that a new
headline appeared on an official site and tells students to read it there. Titles are the sites' own words.

  python pipeline/rrb_notices.py --probe          try every site, print what each returned, change nothing
  python pipeline/rrb_notices.py                  find new titles, update content/notices.json, post to Telegram
  python pipeline/rrb_notices.py --dry-run        like the real run but writes and posts nothing

Many government sites block automated or non-Indian traffic, so every site is optional: a site that does not
answer is skipped and reported in the run summary. The first successful run of a site only records what is
already there (the baseline); it never posts that backlog.
"""
import argparse
import hashlib
import html
import json
import os
import re
import sys
import urllib.request
from datetime import datetime, timedelta, timezone
from html.parser import HTMLParser
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import telegram_bot as tb  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "content/notices.json"
IST = timezone(timedelta(hours=5, minutes=30))
KEEP_DAYS = 45
MAX_POSTED_PER_RUN = 5

# Official sites only. Each one is tried independently; a site that blocks us is simply skipped.
SOURCES = [
    ("RRB Apply", "https://www.rrbapply.gov.in/"),
    ("RRB Chandigarh", "https://www.rrbcdg.gov.in/"),
    ("RRB Mumbai", "https://www.rrbmumbai.gov.in/"),
    ("RRB Ahmedabad", "https://www.rrbahmedabad.gov.in/"),
    ("RRB Allahabad", "https://www.rrbald.gov.in/"),
    ("RRB Bangalore", "https://www.rrbbnc.gov.in/"),
    ("RRB Bhopal", "https://www.rrbbpl.nic.in/"),
    ("RRB Bhubaneswar", "https://www.rrbbbs.gov.in/"),
    ("RRB Chennai", "https://www.rrbchennai.gov.in/"),
    ("RRB Gorakhpur", "https://www.rrbgkp.gov.in/"),
    ("RRB Kolkata", "https://www.rrbkolkata.gov.in/"),
    ("RRB Patna", "https://www.rrbpatna.gov.in/"),
    ("RRB Secunderabad", "https://www.rrbsecunderabad.nic.in/"),
    ("RPF", "https://rpf.indianrailways.gov.in/"),
]
KEYWORDS = re.compile(
    r"\bCEN\b|\bRPF\b|notification|notice|recruitment|result|scorecard|answer key|exam|CBT|"
    r"vacanc|corrigendum|admit card|e-call|schedule|calendar|syllabus|document verification",
    re.I)
# Menus and boilerplate that match the keywords but are not notices.
SKIP = re.compile(r"^(home|about|contact|rti|sitemap|disclaimer|privacy|terms|screen reader|skip to|login|"
                  r"how to apply|faq|feedback|help)\b", re.I)
UA = "Mozilla/5.0 (compatible; RailParikshaNoticeWatch/1.0; +https://t.me/RailParikshaApp)"


class _Links(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self._href, self._text = [], None, []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self._href, self._text = dict(attrs).get("href"), []

    def handle_data(self, data):
        if self._href is not None:
            self._text.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self._href is not None:
            self.links.append((self._href, " ".join("".join(self._text).split())))
            self._href = None


def fetch(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept-Language": "en-IN,en;q=0.8"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read(2_000_000).decode("utf-8", "replace")


def titles_from(page):
    p = _Links()
    p.feed(page)
    seen, out = set(), []
    for href, text in p.links:
        if not 18 <= len(text) <= 220 or SKIP.match(text) or not KEYWORDS.search(text):
            continue
        key = text.lower()
        if key not in seen:
            seen.add(key)
            out.append(text)
    return out


def ident(source, title):
    return hashlib.sha1(f"{source}|{title.lower()}".encode("utf-8")).hexdigest()[:16]


def load():
    try:
        return json.loads(OUT.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {"updated": None, "baselined": [], "items": []}


def probe():
    ok = 0
    for name, url in SOURCES:
        try:
            status, page = fetch(url)
            n = len(titles_from(page))
            ok += bool(n)
            print(f"{name:18} HTTP {status}  {len(page):>7} bytes  {n:>3} candidate notice links  {url}")
        except Exception as e:  # noqa: BLE001
            print(f"{name:18} FAILED  {type(e).__name__}: {str(e)[:90]}  {url}")
    print(f"::notice::{ok} of {len(SOURCES)} official sites gave usable notice links")
    return 0


def telegram_text(new):
    lines = ["📢 <b>आधिकारिक साइट पर नई सूचना</b>", ""]
    for source, title, url in new[:MAX_POSTED_PER_RUN]:
        lines.append(f"• {html.escape(tb.shorten(title, 160))}\n   <i>{html.escape(source)}</i>")
    if len(new) > MAX_POSTED_PER_RUN:
        lines.append(f"…और {len(new) - MAX_POSTED_PER_RUN} सूचनाएँ")
    lines += ["", "ध्यान दें: तारीख, पात्रता और बाकी जानकारी सिर्फ़ आधिकारिक साइट पर देखें। "
                  "हमने कुछ नहीं बदला, सिर्फ़ बताया कि नई सूचना आई है।",
              f"🔗 {html.escape(new[0][2])}"]
    return "\n".join(lines)[:tb.MESSAGE_MAX]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.probe:
        return probe()

    data = load()
    known = {i["id"] for i in data["items"]}
    baselined = set(data.get("baselined", []))
    now = datetime.now(IST)
    new, reached = [], 0
    for name, url in SOURCES:
        try:
            _, page = fetch(url)
        except Exception as e:  # noqa: BLE001
            print(f"::notice::{name} not reachable ({type(e).__name__})")
            continue
        found = titles_from(page)
        if not found:
            print(f"::notice::{name} answered but no notice links were found")
            continue
        reached += 1
        first_time = name not in baselined
        for t in found:
            i = ident(name, t)
            if i in known:
                continue
            known.add(i)
            data["items"].append({"id": i, "source": name, "title": t, "url": url,
                                  "seen": now.date().isoformat(), "baseline": first_time})
            if not first_time:
                new.append((name, t, url))
        baselined.add(name)
    cutoff = (now - timedelta(days=KEEP_DAYS)).date().isoformat()
    data["items"] = [i for i in data["items"] if i["seen"] >= cutoff]
    data["baselined"] = sorted(baselined)
    data["updated"] = now.isoformat(timespec="minutes")
    print(f"sites reached: {reached}/{len(SOURCES)}; new notices: {len(new)}")
    for s, t, _ in new:
        print(f"  NEW [{s}] {t}")
    if args.dry_run:
        return 0
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if new:
        token, chat = os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
        if token and chat:
            tb.Bot(token, chat).message(telegram_text(new))
        else:
            print("::notice::Telegram secrets not set; notices recorded only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
