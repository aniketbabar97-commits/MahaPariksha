"""Daily current-affairs MCQs: news feeds -> Claude draft -> independent blind-solve check.

Only items whose blind solve matches the drafted key are kept; they are appended to
content/bank/current_affairs_auto.json and reach users only after the PR is merged.

Env: ANTHROPIC_API_KEY (required), BHARARI_MODEL (default claude-sonnet-5),
     CA_FEEDS (comma-separated RSS URLs), CA_MAX_ITEMS (default 12).
"""
import json
import os
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path
from typing import List

import anthropic
from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "content/bank/current_affairs_auto.json"
MODEL = os.environ.get("BHARARI_MODEL", "claude-sonnet-5")
FEEDS = [f for f in os.environ.get(
    "CA_FEEDS",
    "https://www.pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3,"
    "https://indianexpress.com/section/india/feed/",
).split(",") if f.strip()]
MAX_ITEMS = int(os.environ.get("CA_MAX_ITEMS", "12"))
TOPICS = ["national", "maharashtra", "international", "schemes", "sci_tech_news", "sports_news", "awards_news"]


class Draft(BaseModel):
    topic: str = Field(description="one of: " + ", ".join(TOPICS))
    q_mr: str
    q_en: str
    o_mr: List[str]
    o_en: List[str]
    a: int
    e_mr: str
    e_en: str
    src: str


class Drafts(BaseModel):
    items: List[Draft]


class Solve(BaseModel):
    answer_index: int
    confident: bool


def fetch_news(days=2):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    news = []
    for url in FEEDS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 BharariBot"})
            root = ET.fromstring(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:  # one broken feed must not stop the run
            print(f"feed failed {url}: {e}", file=sys.stderr)
            continue
        for it in root.iter("item"):
            title = (it.findtext("title") or "").strip()
            link = (it.findtext("link") or "").strip()
            desc = re.sub(r"<[^>]+>", " ", it.findtext("description") or "").strip()
            pub = it.findtext("pubDate")
            try:
                if pub and parsedate_to_datetime(pub) < cutoff:
                    continue
            except (TypeError, ValueError):
                pass
            if title and link:
                news.append({"title": title, "link": link, "summary": desc[:600]})
    return news[:60]


DRAFT_PROMPT = """You write current-affairs MCQs for Marathi-medium aspirants of Maharashtra government exams
(Police Bharti, Talathi, MPSC) and SSC/Railway. From the news items below (published {date}), pick the
{n} most exam-relevant facts (prefer Maharashtra, central schemes, appointments of constitutional posts,
awards, sports, science & technology, international agreements).

Rules:
- Use ONLY facts stated in the given item. Never add facts from memory.
- Put the month and year in the question (e.g. "सप्टेंबर 2026 मध्ये..."), so it stays correct later.
- Exactly one correct option; vary the correct position; plausible distractors.
- o_mr and o_en: 4 options each, same order. a = 0-based correct index.
- e_mr/e_en: 2-3 sentences of context.
- Natural, correct Marathi.
- src = the item's link.

News items:
{items}"""


def draft(client, news):
    items = "\n\n".join(f"- {n['title']}\n  {n['summary']}\n  link: {n['link']}" for n in news)
    r = client.messages.parse(
        model=MODEL,
        max_tokens=16000,
        messages=[{"role": "user", "content": DRAFT_PROMPT.format(
            date=datetime.now().strftime("%B %Y"), n=MAX_ITEMS, items=items)}],
        output_format=Drafts,
    )
    return r.parsed_output.items


def blind_solve(client, d: Draft, source_text: str) -> Solve:
    opts = "\n".join(f"{i}. {o}" for i, o in enumerate(d.o_en))
    r = client.messages.parse(
        model=MODEL,
        max_tokens=2000,
        messages=[{"role": "user", "content":
                   f"Using ONLY this source text, answer the MCQ. If the source does not clearly support "
                   f"exactly one option, set confident=false.\n\nSOURCE:\n{source_text}\n\nQ: {d.q_en}\n{opts}"}],
        output_format=Solve,
    )
    return r.parsed_output


def main():
    news = fetch_news()
    if not news:
        print("no fresh news; nothing to do")
        return 0
    client = anthropic.Anthropic()
    by_link = {n["link"]: n for n in news}
    existing = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else []
    seen_q = {q["q_en"].strip().lower() for q in existing}
    next_n = max([int(q["id"].split("-")[-1]) for q in existing] or [0]) + 1
    kept = []
    for d in draft(client, news):
        src = by_link.get(d.src)
        ok_shape = (len(d.o_mr) == 4 and len(d.o_en) == 4 and 0 <= d.a <= 3 and d.topic in TOPICS
                    and src is not None and d.q_en.strip().lower() not in seen_q)
        if not ok_shape:
            continue
        check = blind_solve(client, d, f"{src['title']}\n{src['summary']}")
        if not check.confident or check.answer_index != d.a:
            print(f"rejected (verification mismatch): {d.q_en[:80]}")
            continue
        kept.append({
            "id": f"caauto-{next_n:05d}", "s": "current_affairs", "t": d.topic, "d": 1,
            "q_mr": d.q_mr, "q_en": d.q_en, "o_mr": d.o_mr, "o_en": d.o_en, "a": d.a,
            "e_mr": d.e_mr, "e_en": d.e_en, "src": d.src,
        })
        next_n += 1
    if kept:
        OUT.write_text(json.dumps(existing + kept, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"kept {len(kept)} verified items")
    return 0


if __name__ == "__main__":
    sys.exit(main())
