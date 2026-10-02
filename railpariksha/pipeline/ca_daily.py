"""Daily railway current-affairs MCQs: news feeds -> Gemini/Grok draft -> cross-model blind-solve check
-> optional Claude quality gate.

Cost-conscious by design: Gemini and Grok do the drafting and the first independent blind-solve
(cross-checked against each other so a single model's mistake cannot slip through). If ANTHROPIC_API_KEY
is also set, every item that already passed the cross-check gets one more blind solve from Claude as the
final accuracy gate -- the "best result" bar -- before it is kept. Nothing reaches users until the item
also passes pipeline/validate.py and a human merges the PR.

Env:
  GEMINI_API_KEY   drafts + cross-checks (used when present; primary drafter)
  GROK_API_KEY     drafts + cross-checks (used when present; drafter if Gemini is unavailable,
                    otherwise the independent cross-checker)
  ANTHROPIC_API_KEY  optional final quality gate (recommended, not required)
  GEMINI_MODEL (default gemini-2.5-flash), GROK_MODEL (default grok-4-fast-reasoning),
  RAILPARIKSHA_CLAUDE_MODEL (default claude-sonnet-5)
  CA_FEEDS (comma-separated RSS URLs), CA_MAX_ITEMS (default 12)

At least one of GEMINI_API_KEY / GROK_API_KEY is required. With only one configured, that model both
drafts and blind-solves its own draft (still gated by validate.py's schema/Devanagari checks), so setting
both -- and ideally ANTHROPIC_API_KEY too -- gives the most reliable results.
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
from typing import List, Optional

from pydantic import BaseModel, Field

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "content/bank/current_affairs_auto.json"
# gemini-2.5-flash's free tier is capped at a hard 20 requests/day (confirmed
# via an actual 429 RESOURCE_EXHAUSTED) and was also seeing persistent 503
# "high demand" errors on a live run -- gemini-flash-lite-latest answered
# immediately with no quota/availability issues in the same run.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-flash-lite-latest")
GROK_MODEL = os.environ.get("GROK_MODEL", "grok-4-fast-reasoning")
CLAUDE_MODEL = os.environ.get("RAILPARIKSHA_CLAUDE_MODEL", "claude-sonnet-5")
FEEDS = [f for f in os.environ.get(
    "CA_FEEDS",
    "https://pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3,"
    "https://indianexpress.com/section/india/feed/,"
    "https://www.thehindu.com/news/national/feeder/default.rss",
).split(",") if f.strip()]
MAX_ITEMS = int(os.environ.get("CA_MAX_ITEMS", "12"))
TOPICS = ["national", "international", "sports_news", "awards_news", "schemes",
          "appointments", "sci_tech_news", "banking_finance", "railway_current_affairs"]


class Draft(BaseModel):
    topic: str = Field(description="one of: " + ", ".join(TOPICS))
    q_hi: str
    q_en: str
    o_hi: List[str]
    o_en: List[str]
    a: int
    e_hi: str
    e_en: str
    src: str


class Drafts(BaseModel):
    items: List[Draft]


class Solve(BaseModel):
    answer_index: int
    confident: bool


DRAFT_PROMPT = """You write current-affairs MCQs for Hindi-medium aspirants preparing for Indian Railways
recruitment exams (RRB NTPC, RRB Group D, RRB ALP/JE, RPF Constable & SI). From the news items below
(published {date}), pick the {n} most exam-relevant facts (prefer railways & transport, national schemes,
appointments of constitutional/public posts, awards, sports, science & technology, defence, banking).

Rules:
- Use ONLY facts stated in the given item. Never add facts from memory.
- Put the month and year in the question (e.g. "सितंबर 2026 में..."), so it stays correct later.
- Exactly one correct option; vary the correct position; plausible distractors.
- o_hi and o_en: 4 options each, same order. a = 0-based correct index.
- e_hi/e_en: 2-3 sentences of context.
- Natural, correct, exam-register Hindi (Devanagari), not machine-translated English.
- src = the item's link.
- topic must be one of: {topics}

Respond with ONLY a JSON object of the shape {{"items": [{{"topic": ..., "q_hi": ..., "q_en": ...,
"o_hi": [...4 strings...], "o_en": [...4 strings...], "a": 0, "e_hi": ..., "e_en": ..., "src": ...}}]}}.
No markdown fences, no commentary.

News items:
{items}"""

SOLVE_PROMPT = """Using ONLY this source text, answer the MCQ. If the source does not clearly support
exactly one option, set confident=false.

SOURCE:
{source}

Q: {q}
{opts}

Respond with ONLY a JSON object: {{"answer_index": 0, "confident": true}}"""


def _extract_json(text: str) -> str:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip(), flags=re.MULTILINE)
    return text.strip()


class GeminiBackend:
    name = "gemini"

    def __init__(self):
        from google import genai
        self.client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])

    def _generate(self, prompt: str, schema) -> str:
        resp = self.client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
            config={"response_mime_type": "application/json", "response_schema": schema},
        )
        return resp.text

    def draft(self, prompt: str) -> Drafts:
        return Drafts.model_validate_json(_extract_json(self._generate(prompt, Drafts)))

    def solve(self, prompt: str) -> Solve:
        return Solve.model_validate_json(_extract_json(self._generate(prompt, Solve)))


class GrokBackend:
    name = "grok"

    def __init__(self):
        from openai import OpenAI
        self.client = OpenAI(api_key=os.environ["GROK_API_KEY"], base_url="https://api.x.ai/v1")

    def _generate(self, prompt: str) -> str:
        resp = self.client.chat.completions.create(
            model=GROK_MODEL,
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"},
        )
        return resp.choices[0].message.content

    def draft(self, prompt: str) -> Drafts:
        return Drafts.model_validate_json(_extract_json(self._generate(prompt)))

    def solve(self, prompt: str) -> Solve:
        return Solve.model_validate_json(_extract_json(self._generate(prompt)))


class ClaudeGate:
    """Final accuracy gate: only used to blind-solve items that already passed the cheaper cross-check."""
    name = "claude"

    def __init__(self):
        import anthropic
        self.client = anthropic.Anthropic()

    def solve(self, prompt: str) -> Solve:
        r = self.client.messages.parse(
            model=CLAUDE_MODEL, max_tokens=1000,
            messages=[{"role": "user", "content": prompt}], output_format=Solve,
        )
        return r.parsed_output


def fetch_news(days=2):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    news = []
    for url in FEEDS:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 RailParikshaBot"})
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


def build_backends():
    backends = []
    if os.environ.get("GEMINI_API_KEY"):
        backends.append(GeminiBackend())
    if os.environ.get("GROK_API_KEY"):
        backends.append(GrokBackend())
    if not backends:
        sys.exit("set GEMINI_API_KEY and/or GROK_API_KEY")
    return backends


def blind_solve(backend, d: Draft, source_text: str) -> Solve:
    opts = "\n".join(f"{i}. {o}" for i, o in enumerate(d.o_en))
    prompt = SOLVE_PROMPT.format(source=source_text, q=d.q_en, opts=opts)
    return backend.solve(prompt)


def main():
    news = fetch_news()
    if not news:
        print("no fresh news; nothing to do")
        return 0
    backends = build_backends()
    drafter = backends[0]
    checker = backends[1] if len(backends) > 1 else backends[0]
    claude_gate: Optional[ClaudeGate] = ClaudeGate() if os.environ.get("ANTHROPIC_API_KEY") else None

    by_link = {n["link"]: n for n in news}
    existing = json.loads(OUT.read_text(encoding="utf-8")) if OUT.exists() else []
    seen_q = {q["q_en"].strip().lower() for q in existing}
    next_n = max([int(q["id"].split("-")[-1]) for q in existing] or [0]) + 1

    prompt = DRAFT_PROMPT.format(
        date=datetime.now().strftime("%B %Y"), n=MAX_ITEMS, topics=", ".join(TOPICS),
        items="\n\n".join(f"- {n['title']}\n  {n['summary']}\n  link: {n['link']}" for n in news),
    )
    print(f"drafting with {drafter.name}, cross-checking with {checker.name}"
          + (", final gate: claude" if claude_gate else ""))
    drafts = drafter.draft(prompt).items

    kept = []
    for d in drafts:
        src = by_link.get(d.src)
        ok_shape = (len(d.o_hi) == 4 and len(d.o_en) == 4 and 0 <= d.a <= 3 and d.topic in TOPICS
                    and src is not None and d.q_en.strip().lower() not in seen_q)
        if not ok_shape:
            continue
        source_text = f"{src['title']}\n{src['summary']}"
        cross = blind_solve(checker, d, source_text)
        if not cross.confident or cross.answer_index != d.a:
            print(f"rejected ({checker.name} mismatch): {d.q_en[:80]}")
            continue
        if claude_gate:
            gate = blind_solve(claude_gate, d, source_text)
            if not gate.confident or gate.answer_index != d.a:
                print(f"rejected (claude gate mismatch): {d.q_en[:80]}")
                continue
        kept.append({
            "id": f"caauto-{next_n:05d}", "s": "current_affairs", "t": d.topic, "d": 1,
            "q_hi": d.q_hi, "q_en": d.q_en, "o_hi": d.o_hi, "o_en": d.o_en, "a": d.a,
            "e_hi": d.e_hi, "e_en": d.e_en, "src": d.src,
        })
        next_n += 1
    if kept:
        OUT.write_text(json.dumps(existing + kept, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"kept {len(kept)} verified items")
    return 0


if __name__ == "__main__":
    sys.exit(main())
