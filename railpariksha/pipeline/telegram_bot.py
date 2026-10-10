"""Telegram channel automation for RailPariksha: everything the channel posts comes from this one script.

The owner only creates the channel, adds the bot as an admin (post messages, pin messages, change
channel info) and sets two GitHub secrets, TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID. After that the
scheduled workflow (.github/workflows/railpariksha_telegram.yml, plus the daily current-affairs job)
runs these slots, all in Hindi, all from content already in the repo:

  ca            ~06:50 IST  picture card + short digest of the day's current affairs, then a quiz poll
  poll_morning  08:00       a real previous-year question as a quiz poll (maths / reasoning)
  fact          11:00       a flashcard with the answer hidden behind a spoiler, or a cheat-sheet card
  poll_noon     13:30       quiz poll (science / railway GK / computer / reasoning)
  tip           17:00       a motivation or study tip, today's special day, and the app link
  poll_evening  20:00       quiz poll (general knowledge / railway GK / current affairs)
  weekly        Sun 19:00   the week's current affairs in one post
  announce      manual      posts the text given with --text (the owner's own notices)
  refresh       manual      rewrites the description and pins a fresh welcome message
  setup         automatic   description + a pinned welcome message; runs by itself when nothing is pinned

Quiz polls carry the real answer and a Hindi explanation (Telegram shows it after a vote), and every
poll question is a PYQ that already has a worked explanation, so the channel doubles as proof of the
app's content. Choices rotate deterministically by date, so no state is stored and nothing repeats for
months.

  python pipeline/telegram_bot.py --slot poll_morning --dry-run     # show what would be sent, send nothing
  python pipeline/telegram_bot.py --slot ca --dry-run --out /tmp/x   # also writes the picture card
"""
import argparse
import html
import io
import json
import os
import random
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ca_post  # noqa: E402  (same folder; holds the Play link and Hindi month names)

ROOT = Path(__file__).resolve().parent.parent
PYQ_DIR = ROOT / "content/pyq"
CONTENT = ROOT / "content"
FONTS = ROOT / "app/assets/fonts"
PLAY_URL = ca_post.PLAY_URL
SITE_URL = "https://railpariksha.in"
IST = timezone(timedelta(hours=5, minutes=30))

# Telegram's own limits for quiz polls and captions.
POLL_QUESTION_MAX = 290  # Telegram allows 300; a little headroom in case it counts emoji as two
POLL_OPTION_MAX = 100
POLL_EXPLANATION_MAX = 200
CAPTION_MAX = 1024
MESSAGE_MAX = 4096

SUBJECT_HI = {
    "maths": "गणित", "reasoning": "रीज़निंग", "science": "विज्ञान", "gk": "सामान्य ज्ञान",
    "railway_gk": "रेलवे ज्ञान", "computer": "कंप्यूटर", "english": "अंग्रेज़ी", "current_affairs": "करेंट अफेयर्स",
}

# (slot number, subject for each weekday Monday..Sunday)
POLL_SLOTS = {
    "poll_morning": (0, ["maths", "reasoning", "maths", "reasoning", "maths", "reasoning", "maths"]),
    "poll_noon": (1, ["science", "reasoning", "railway_gk", "science", "reasoning", "computer", "science"]),
    "poll_evening": (2, ["gk", "railway_gk", "gk", "current_affairs", "gk", "railway_gk", "gk"]),
}
# The hourly quiz: one subject per slot from this cycle. Its length is odd on purpose, so the subject does not
# line up with the language (which alternates every hour).
QUIZ_CYCLE = ["maths", "reasoning", "gk", "science", "maths", "reasoning", "gk", "railway_gk", "science",
              "computer", "reasoning"]
SUBJECT_EN = {
    "maths": "Maths", "reasoning": "Reasoning", "science": "Science", "gk": "General Knowledge",
    "railway_gk": "Railway GK", "computer": "Computer", "english": "English", "current_affairs": "Current Affairs",
}
SLOTS = ["ca", *POLL_SLOTS, "quiz", "fact", "tip", "weekly", "announce", "setup", "refresh"]

GENERIC = re.compile(r"official answer key|आधिकारिक उत्तर कुंजी|published answer key|प्रकाशित उत्तर कुंजी", re.I)
# Anything that needs a picture, a diagram or a seating layout is skipped: a poll is text only.
VISUAL = re.compile(
    r"figure|diagram|image|picture|graph|chart|table|venn|mirror|dice|cube|चित्र|आकृति|ग्राफ|तालिका|आरेख|वेन|दर्पण|प्रतिबिंब|पासा", re.I)

WELCOME = (
    "🚆 <b>नमस्ते दोस्तों! हम भी आप ही की तरह रेलवे की तैयारी कर रहे हैं।</b>\n"
    "RailPariksha स्टूडेंट्स ने स्टूडेंट्स के लिए बनाया है। कोई कोचिंग नहीं, कोई बड़ा दावा नहीं, बस रोज़ की मेहनत।\n\n"
    "इस चैनल पर हर दिन:\n"
    "📰 सुबह: आज का करेंट अफेयर्स\n"
    "📝 दिन में 3 क्विज़, असली पिछले साल के प्रश्न (जवाब और व्याख्या के साथ)\n"
    "🧠 फ़ैक्ट, फ़ॉर्मूला और चीट शीट\n"
    "💪 शाम को पढ़ाई की टिप\n\n"
    f"📲 हमारा मुफ़्त ऐप (हिंदी + अंग्रेज़ी, ऑफलाइन भी): {PLAY_URL}\n"
    f"🌐 वेबसाइट: {SITE_URL}\n\n"
    "कोई प्रश्न गलत लगे तो ऐप में Report कर दीजिए, हम सुधारते हैं। साथ पढ़ेंगे तो साथ निकलेंगे 🤝"
)
DESCRIPTION = (
    "हम भी आपकी तरह रेलवे की तैयारी कर रहे स्टूडेंट्स हैं। रोज़: करेंट अफेयर्स, PYQ क्विज़, फ़ैक्ट। "
    f"स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए। ऐप: {PLAY_URL} · वेबसाइट: {SITE_URL}"
)


class TelegramError(Exception):
    def __init__(self, code, description):
        super().__init__(f"Telegram error {code}: {description}")
        self.code = code
        self.description = description


# ---------------------------------------------------------------------------------------------
# Content selection (pure functions, covered by test_telegram_bot.py)
# ---------------------------------------------------------------------------------------------

def today_ist(now=None):
    return (now or datetime.now(IST)).astimezone(IST).date()


def shorten(text, limit):
    """Cut at a sentence end if one fits, else at a word, adding an ellipsis; never exceeds limit."""
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    cut = text[:limit]
    for mark in ("। ", ". "):
        i = cut.rfind(mark)
        if i >= limit * 0.4:
            return cut[: i + 1].strip()
    cut = text[: limit - 1]
    i = cut.rfind(" ")
    return (cut[:i] if i > limit * 0.5 else cut).rstrip(" ,;:") + "…"


def exam_label(pyq):
    """'RRB JE CBT-1 · 16 Dec 2024 · Shift 1' -> 'RRB JE CBT-1 · 16 Dec 2024'."""
    parts = [p.strip() for p in (pyq or "").split(" · ") if p.strip()]
    return " · ".join(parts[:2])


def poll_ok(q):
    """Whether a question can be a clean text-only Hindi quiz poll."""
    try:
        opts, a = q["o_hi"], q["a"]
        if not isinstance(a, int) or not 2 <= len(opts) <= 10 or not 0 <= a < len(opts):
            return False
        if len(set(opts)) != len(opts) or any(not o.strip() or len(o) > POLL_OPTION_MAX for o in opts):
            return False
        text = q["q_hi"]
        if not text.strip() or len(text) > POLL_QUESTION_MAX - 60:
            return False
        if VISUAL.search(text) or VISUAL.search(q.get("q_en") or "") or any(VISUAL.search(o) for o in opts):
            return False
        e_hi, e_en = q.get("e_hi") or "", q.get("e_en") or ""
        if not e_hi.strip() or GENERIC.search(e_hi) or GENERIC.search(e_en):
            return False
        # The Hindi has to be real Hindi: some items are English only.
        return bool(re.search(r"[ऀ-ॿ]", text))
    except (KeyError, TypeError, AttributeError):
        return False


def poll_ok_en(q):
    """Whether a question can be a clean text-only English quiz poll."""
    try:
        opts, a = q["o_en"], q["a"]
        if not isinstance(a, int) or len(opts) != 4 or not 0 <= a < 4:
            return False
        if len(set(opts)) != 4 or any(not o.strip() or len(o) > POLL_OPTION_MAX for o in opts):
            return False
        text = q["q_en"]
        if not re.search(r"[A-Za-z]{3}", text) or len(text) > POLL_QUESTION_MAX - 60:
            return False
        if VISUAL.search(text) or any(VISUAL.search(o) for o in opts) or VISUAL.search(q.get("q_hi") or ""):
            return False
        e_en = q.get("e_en") or ""
        return bool(e_en.strip()) and not GENERIC.search(e_en) and not GENERIC.search(q.get("e_hi") or "")
    except (KeyError, TypeError, AttributeError):
        return False


def poll_payload(q, chat_id, prefix, lang="hi"):
    label = exam_label(q.get("pyq"))
    head = f"{prefix} {label}".strip() if label else prefix
    text = q["q_en" if lang == "en" else "q_hi"].strip()
    question = f"{head}\n{text}"
    if len(question) > POLL_QUESTION_MAX:
        question = f"{prefix}\n{text}"
    return {
        "chat_id": chat_id,
        "question": question[:POLL_QUESTION_MAX],
        "options": [o.strip() for o in q["o_en" if lang == "en" else "o_hi"]],
        "type": "quiz",
        "correct_option_id": q["a"],
        "explanation": shorten(q["e_en" if lang == "en" else "e_hi"], POLL_EXPLANATION_MAX),
        "is_anonymous": True,
    }


_POOLS = {}


def load_pyq(subject, lang="hi"):
    """Every PYQ of a subject that can be a clean poll in a language. The packs are read once per run."""
    if not _POOLS:
        for p in sorted(PYQ_DIR.glob("*.json")):
            for r in json.loads(p.read_text(encoding="utf-8")):
                for lg, ok in (("hi", poll_ok), ("en", poll_ok_en)):
                    if ok(r):
                        _POOLS.setdefault((lg, r.get("s")), []).append(r)
    return _POOLS.get((lang, subject), [])


def rotation(now_ist=None):
    """(slot number, language) of an hour in India. The slot number grows by one every hour, so each hour gets
    its own question; the language alternates hourly and flips every day, so a given clock hour is Hindi one
    day and English the next."""
    now = (now_ist or datetime.now(IST)).astimezone(IST)
    n = now.date().toordinal() * 24 + now.hour
    return n, "en" if (now.date().toordinal() + now.hour) % 2 else "hi"


def cycle_step(n):
    """(subject, step) of slot number n: the subject from QUIZ_CYCLE and how many times that subject has come
    up before, which is its position in its own shuffle."""
    pos = n % len(QUIZ_CYCLE)
    subject = QUIZ_CYCLE[pos]
    return subject, (n // len(QUIZ_CYCLE)) * QUIZ_CYCLE.count(subject) + QUIZ_CYCLE[:pos].count(subject)


def quiz_for(n, lang, chat_id, pools=None):
    """The hourly quiz poll for slot number n, or None. Each subject walks its own fixed shuffle one step at a
    time, so nothing repeats until the subject's whole pool has been used."""
    subject, step = cycle_step(n)
    pool = (pools or {}).get(subject) if pools is not None else load_pyq(subject, lang)
    if not pool:
        return None
    ordered = sorted(pool, key=lambda r: r.get("id", ""))
    random.Random(f"railpariksha-hourly-{lang}-{subject}").shuffle(ordered)
    q = ordered[step % len(ordered)]
    prefix = f"🚆 {SUBJECT_EN[subject]} PYQ ·" if lang == "en" else f"🚆 {SUBJECT_HI[subject]} PYQ ·"
    return poll_payload(q, chat_id, prefix, lang)


def pick(pool, key, day, offset=0):
    """Deterministic, repeat-free rotation: one fixed shuffle of the pool, one step per day."""
    if not pool:
        return None
    ordered = sorted(pool, key=lambda r: r.get("id", ""))
    random.Random(f"railpariksha-{key}").shuffle(ordered)
    return ordered[(day.toordinal() + offset) % len(ordered)]


def poll_for(slot, day, chat_id, pools=None):
    """The quiz poll for a PYQ slot on a given day, or None when nothing is eligible."""
    n, subjects = POLL_SLOTS[slot]
    subject = subjects[day.weekday()]
    pool = (pools or {}).get(subject) if pools is not None else load_pyq(subject)
    q = pick(pool, subject, day, offset=n * 7)
    if q is None:
        return None
    return poll_payload(q, chat_id, "🚆 PYQ")


def feed_days():
    qs = json.loads((CONTENT / "ca_feed.json").read_text(encoding="utf-8"))["questions"]
    by = {}
    for q in qs:
        by.setdefault(q["date"], []).append(q)
    return by


def fact_of_headline(q):
    return q["e_hi"].split("।")[0].strip() + "।"


def distinct_stories(qs):
    """The feed can hold several questions on one story; a digest should list each story once."""
    seen, out = [], []
    for q in qs:
        # Content words only: Hindi particles (के, में, ने, को ...) are three characters or fewer.
        words = {w.strip("।,.;:()'\"") for w in fact_of_headline(q).split()}
        words = {w for w in words if len(w) > 3}
        if any(len(words & w) / max(1, min(len(words), len(w))) > 0.5 for w in seen):
            continue
        seen.append(words)
        out.append(q)
    return out


def ca_poll_payload(q, chat_id):
    if not poll_ok(q):
        return None
    return poll_payload(q, chat_id, "📰 करेंट अफेयर्स")


def hindi_date(day):
    return f"{day.day} {ca_post.MONTHS_HI[day.month - 1]} {day.year}"


def ca_caption(day, qs):
    """Digest as a photo caption: as many headlines as fit in Telegram's 1024 characters."""
    head = f"📰 <b>आज का करेंट अफेयर्स: {hindi_date(day)}</b>\nरेलवे परीक्षा के लिए ज़रूरी बातें:\n\n"
    foot = f"\n📲 पूरी क्विज़ और 45,000+ PYQ ऐप में: {PLAY_URL}\n#RRB #RailwayExam #CurrentAffairs"
    body = ""
    for i, q in enumerate(qs, 1):
        line = f"{i}. {html.escape(fact_of_headline(q))}\n"
        if len(head) + len(body) + len(line) + len(foot) > CAPTION_MAX:
            break
        body += line
    return head + body + foot


def ca_text(day, qs):
    lines = [f"📰 <b>आज का करेंट अफेयर्स: {hindi_date(day)}</b>", "रेलवे परीक्षा के लिए ज़रूरी बातें:", ""]
    lines += [f"{i}. {html.escape(fact_of_headline(q))}" for i, q in enumerate(qs, 1)]
    lines += ["", f"📲 पूरी क्विज़ और 45,000+ PYQ ऐप में: {PLAY_URL}", "", "#RRB #RailwayExam #CurrentAffairs"]
    return "\n".join(lines)[:MESSAGE_MAX]


def _flashcards():
    out = []
    for p in sorted((CONTENT / "flashcards").glob("*.json")):
        if p.stem.startswith("je_"):
            continue
        out += [c for c in json.loads(p.read_text(encoding="utf-8")) if c.get("f_hi") and c.get("b_hi")]
    return out


def _cheat_items():
    out = []
    for p in sorted((CONTENT / "cheat_sheets").glob("*.json")):
        if p.stem.startswith("je_"):
            continue
        for c in json.loads(p.read_text(encoding="utf-8")):
            if c.get("items_hi") and c.get("cat_hi"):
                out.append(c)
    return out


def fact_text(day):
    """Two days in three a flashcard with a hidden answer, every third day a cheat-sheet card."""
    if day.toordinal() % 3 == 0:
        sheet = pick(_cheat_items(), "cheat", day)
        label = SUBJECT_HI.get(sheet["s"], "")
        items = "\n".join(f"• {html.escape(i)}" for i in sheet["items_hi"][:6])
        return (f"📌 <b>चीट शीट: {html.escape(sheet['cat_hi'])}</b>"
                + (f" ({label})" if label else "") + f"\n\n{items}\n\n🔖 सेव कर लें, परीक्षा से पहले काम आएगा।")
    card = pick(_flashcards(), "fact", day)
    label = SUBJECT_HI.get(card["s"], "")
    return (f"🧠 <b>आज का फ़ैक्ट</b>" + (f" ({label})" if label else "") + f"\n\n❓ {html.escape(card['f_hi'])}\n\n"
            f"👇 जवाब देखने के लिए टैप करें\n<tg-spoiler>✅ {html.escape(card['b_hi'])}</tg-spoiler>")


def special_day(day):
    """'12 जनवरी — राष्ट्रीय युवा दिवस' style entries from the GK booster that fall on this date."""
    booster = json.loads((CONTENT / "gk_booster.json").read_text(encoding="utf-8"))
    def norm(t):
        return t.replace("़", "")  # फ़रवरी / फरवरी

    month = norm(ca_post.MONTHS_HI[day.month - 1])
    hits = []
    for cat in booster["categories"]:
        if cat["id"] != "important_days":
            continue
        for item in cat["items"]:
            m = re.match(r"^\s*(\d{1,2})\s+(\S+)\s+[—-]", item["title_hi"])
            if m and int(m.group(1)) == day.day and norm(m.group(2)) == month:
                hits.append(item)
    return hits


def tip_text(day):
    items = json.loads((CONTENT / "motivation/motivation.json").read_text(encoding="utf-8"))
    item = pick([i for i in items if i.get("hi")], "tip", day)
    icon = {"quote": "💬", "tip": "💡", "story": "📖"}.get(item.get("type"), "💪")
    parts = [f"{icon} {html.escape(item['hi'])}"]
    for s in special_day(day):
        parts.append(f"📅 <b>आज:</b> {html.escape(s['title_hi'])}\n{html.escape(s.get('detail_hi', ''))}")
    parts.append(f"🚆 आज की प्रैक्टिस अभी करें, रोज़ 10 प्रश्न भी काफ़ी हैं:\n{PLAY_URL}\n🌐 {SITE_URL}")
    return "\n\n".join(parts)[:MESSAGE_MAX]


def weekly_text(day):
    by = {d: distinct_stories(v) for d, v in feed_days().items()}
    days = sorted(d for d in by if date.fromisoformat(d) > day - timedelta(days=7))
    lines = [f"🗓️ <b>इस हफ़्ते का करेंट अफेयर्स ({hindi_date(day - timedelta(days=6))} से {hindi_date(day)})</b>", ""]
    n = 0
    for d in days:
        for q in by[d]:
            line = f"{n + 1}. {html.escape(fact_of_headline(q))}"
            if sum(len(x) + 1 for x in lines) + len(line) > MESSAGE_MAX - 400:
                break
            lines.append(line)
            n += 1
    if n == 0:
        return None
    lines += ["", f"📲 पूरी क्विज़ और मॉक टेस्ट ऐप में: {PLAY_URL}", f"🌐 {SITE_URL}", "", "#WeeklyRecap #CurrentAffairs #RRB"]
    return "\n".join(lines)


# ---------------------------------------------------------------------------------------------
# Picture card
# ---------------------------------------------------------------------------------------------

def card_available():
    try:
        from PIL import features
        return features.check("raqm")  # without it Devanagari conjuncts render wrongly, so skip the card instead
    except Exception:  # noqa: BLE001
        return False


def make_card(day, qs, count=4):
    """A 1080x1350 PNG of the day's headlines (returns bytes), or None when it cannot render Hindi safely."""
    if not card_available():
        return None
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    W, H = 1080, 1350
    top, bottom = (10, 22, 51), (20, 38, 79)
    img = Image.new("RGB", (W, H), top)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    glow = Image.new("RGB", (W, H), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((500, 950, 1500, 1750), fill=(255, 120, 40))
    img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(220)), 0.30)
    d = ImageDraw.Draw(img)
    f_title = ImageFont.truetype(str(FONTS / "Mukta-ExtraBold.ttf"), 78)
    f_date = ImageFont.truetype(str(FONTS / "Mukta-SemiBold.ttf"), 40)
    f_text = ImageFont.truetype(str(FONTS / "Mukta-SemiBold.ttf"), 40)
    f_num = ImageFont.truetype(str(FONTS / "Mukta-ExtraBold.ttf"), 44)
    f_foot = ImageFont.truetype(str(FONTS / "Mukta-Bold.ttf"), 38)

    d.text((70, 70), "RailPariksha", font=f_date, fill=(255, 196, 60))
    d.text((70, 120), "आज का करेंट अफेयर्स", font=f_title, fill=(255, 255, 255))
    d.text((70, 235), hindi_date(day), font=f_date, fill=(190, 215, 255))

    def wrap(text, width, max_lines):
        lines, cur = [], ""
        for w in text.split():
            t = (cur + " " + w).strip()
            if d.textlength(t, font=f_text) <= width:
                cur = t
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
        if len(lines) > max_lines:
            lines = lines[:max_lines]
            last = lines[-1]
            while last and d.textlength(last + "…", font=f_text) > width:
                last = last.rsplit(" ", 1)[0] if " " in last else last[:-1]
            lines[-1] = last + "…"
        return lines

    y = 330
    area = H - 330 - 190
    n = min(count, len(qs))
    gap = 26
    box_h = min((area - gap * (n - 1)) // max(n, 1), 300)
    y += (area - (box_h * n + gap * (n - 1))) // 2  # few stories: centre the stack instead of stretching boxes
    for i, q in enumerate(qs[:n], 1):
        d.rounded_rectangle((60, y, W - 60, y + box_h), radius=34, fill=(16, 52, 120))
        d.ellipse((90, y + 28, 154, y + 92), fill=(255, 196, 60))
        nb = d.textbbox((0, 0), str(i), font=f_num)
        d.text((122 - (nb[2] - nb[0]) / 2, 40 + y - nb[1] + 0), str(i), font=f_num, fill=(11, 38, 92))
        lines = wrap(fact_of_headline(q), W - 120 - 110 - 40, max(2, (box_h - 40) // 52))
        ty = y + 26
        for ln in lines:
            d.text((190, ty), ln, font=f_text, fill=(255, 255, 255))
            ty += 52
        y += box_h + gap
    d.text((70, H - 150), "रोज़ की तैयारी, मुफ़्त ऐप में", font=f_foot, fill=(255, 196, 60))
    d.text((70, H - 100), "45,000+ असली PYQ • Play Store: RailPariksha", font=f_date, fill=(220, 235, 255))
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


# ---------------------------------------------------------------------------------------------
# Telegram transport
# ---------------------------------------------------------------------------------------------

class Bot:
    def __init__(self, token, chat_id, dry_run=False, out=None):
        self.token, self.chat_id, self.dry_run = token, chat_id, dry_run
        self.out = Path(out) if out else None
        self.sent = 0

    def _call(self, method, payload=None, files=None):
        if self.dry_run:
            shown = {k: (v if k != "chat_id" else "<chat>") for k, v in (payload or {}).items()}
            print(f"[dry-run] {method}: {json.dumps(shown, ensure_ascii=False, indent=1)}" + (" + photo" if files else ""))
            return {"ok": True, "result": {}}
        url = f"https://api.telegram.org/bot{self.token}/{method}"
        for attempt in range(5):
            if files:
                boundary = uuid.uuid4().hex
                body = b""
                for k, v in (payload or {}).items():
                    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n").encode()
                for k, (fname, data) in files.items():
                    body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{fname}\"\r\n"
                             "Content-Type: image/png\r\n\r\n").encode() + data + b"\r\n"
                body += f"--{boundary}--\r\n".encode()
                req = urllib.request.Request(url, data=body, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})
            else:
                req = urllib.request.Request(url, data=json.dumps(payload or {}).encode(),
                                             headers={"Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(req, timeout=40) as r:
                    return json.loads(r.read())
            except urllib.error.HTTPError as e:
                try:
                    body = json.loads(e.read() or b"{}")
                except ValueError:
                    body = {}
                if e.code == 429:
                    time.sleep(min(int(body.get("parameters", {}).get("retry_after", 5)), 60) + 1)
                    continue
                if e.code >= 500:
                    time.sleep(2 ** attempt)
                    continue
                raise TelegramError(e.code, body.get("description", "")) from None
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                time.sleep(2 ** attempt)
        raise TelegramError(0, "no response after retries")

    def message(self, text, pin=False):
        r = self._call("sendMessage", {"chat_id": self.chat_id, "text": text, "parse_mode": "HTML",
                                       "disable_web_page_preview": True})
        self.sent += 1
        if pin and not self.dry_run:
            self._call("pinChatMessage", {"chat_id": self.chat_id, "message_id": r["result"]["message_id"],
                                          "disable_notification": True})
        return r

    def photo(self, png, caption):
        r = self._call("sendPhoto", {"chat_id": self.chat_id, "caption": caption, "parse_mode": "HTML"},
                       files={"photo": ("card.png", png)})
        self.sent += 1
        return r

    def poll(self, payload):
        payload = {**payload, "chat_id": self.chat_id}
        r = self._call("sendPoll", payload)
        self.sent += 1
        return r

    def refresh_setup(self):
        """Owner-triggered: overwrite the description and pin a new welcome post."""
        if self.dry_run:
            print("[dry-run] refresh: would rewrite the description and pin a new welcome message")
            return
        try:
            self._call("setChatDescription", {"chat_id": self.chat_id, "description": DESCRIPTION[:255]})
        except TelegramError as e:
            if "not modified" not in e.description:
                print(f"::warning::could not set the channel description ({e.description}); give the bot 'Change channel info'")
        self.message(WELCOME, pin=True)

    def ensure_setup(self):
        """Description plus a pinned welcome post, only when the channel has none yet (stateless)."""
        if self.dry_run:
            print("[dry-run] setup: would set the description and pin the welcome message if nothing is pinned")
            return
        info = self._call("getChat", {"chat_id": self.chat_id}).get("result", {})
        if not info.get("description"):
            try:
                self._call("setChatDescription", {"chat_id": self.chat_id, "description": DESCRIPTION[:255]})
            except TelegramError as e:
                print(f"::warning::could not set the channel description ({e.description}); give the bot 'Change channel info'")
        if not info.get("pinned_message"):
            try:
                self.message(WELCOME, pin=True)
            except TelegramError as e:
                print(f"::warning::could not pin the welcome message ({e.description}); give the bot 'Pin messages'")

    def member_count(self):
        try:
            return self._call("getChatMemberCount", {"chat_id": self.chat_id}).get("result")
        except TelegramError:
            return None


# ---------------------------------------------------------------------------------------------
# Slots
# ---------------------------------------------------------------------------------------------

def run_slot(bot, slot, day, text=None, out=None, hour=None):
    if slot == "setup":
        bot.ensure_setup()
        return
    if slot == "refresh":
        bot.refresh_setup()
        return
    if slot == "announce":
        if not text:
            raise SystemExit("announce needs --text")
        bot.message(html.escape(text))
        return
    bot.ensure_setup()
    if slot == "ca":
        by = feed_days()
        newest = max(by) if by else None
        if not newest or (day - date.fromisoformat(newest)).days > 1:
            print("::notice::no fresh current-affairs day (newest is "
                  f"{newest}); skipping today's digest instead of posting something old")
            return
        qs = by[newest]
        d = date.fromisoformat(newest)
        stories = distinct_stories(qs)
        png = make_card(d, stories)
        if png:
            if out:
                Path(out).mkdir(parents=True, exist_ok=True)
                (Path(out) / "card.png").write_bytes(png)
            bot.photo(png, ca_caption(d, stories))
        else:
            print("::notice::picture card unavailable (Pillow without raqm); posting text only")
            bot.message(ca_text(d, stories))
        for q in qs:
            payload = ca_poll_payload(q, bot.chat_id)
            if payload:
                bot.poll(payload)
                break
    elif slot == "quiz":
        when = datetime.now(IST) if hour is None else datetime(day.year, day.month, day.day, hour, tzinfo=IST)
        n, lang = rotation(when)
        payload = quiz_for(n, lang, bot.chat_id)
        if payload is None:
            print(f"::warning::no eligible {lang} question for slot {n}")
            return
        bot.poll(payload)
    elif slot in POLL_SLOTS:
        payload = poll_for(slot, day, bot.chat_id)
        if payload is None:
            print(f"::warning::no eligible question for {slot}")
            return
        bot.poll(payload)
    elif slot == "fact":
        bot.message(fact_text(day))
    elif slot == "tip":
        bot.message(tip_text(day))
    elif slot == "weekly":
        text = weekly_text(day)
        if text:
            bot.message(text)
        else:
            print("::notice::no current affairs in the last week; no recap")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slot", required=True, choices=SLOTS)
    ap.add_argument("--date", help="YYYY-MM-DD (default: today in India)")
    ap.add_argument("--text", help="message for the announce slot")
    ap.add_argument("--hour", type=int, help="hour in India for the hourly quiz (default: now)")
    ap.add_argument("--dry-run", action="store_true", help="print what would be sent; send nothing")
    ap.add_argument("--out", help="folder to also write the picture card to")
    a = ap.parse_args()
    day = date.fromisoformat(a.date) if a.date else today_ist()
    token, chat = os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    if not a.dry_run and (not token or not chat):
        print("::notice::TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID not set; nothing posted")
        return 0
    bot = Bot(token, chat, dry_run=a.dry_run, out=a.out)
    try:
        run_slot(bot, a.slot, day, text=a.text, out=a.out, hour=a.hour)
        if not a.dry_run:
            members = bot.member_count()
            line = f"Telegram slot `{a.slot}` posted {bot.sent} message(s); channel members: {members}"
            print(line)
            summary = os.environ.get("GITHUB_STEP_SUMMARY")
            if summary:
                with open(summary, "a", encoding="utf-8") as f:
                    f.write(line + "\n")
    except TelegramError as e:
        print(f"::error::{e}. Check that the bot is an admin of the channel and that TELEGRAM_CHAT_ID is right.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
