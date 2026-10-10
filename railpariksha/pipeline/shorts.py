#!/usr/bin/env python3
"""YouTube Shorts for RailPariksha, built from the same previous-year questions as the Telegram quizzes.

One vertical (1080x1920) video of about 20 seconds per run: the question and four options, a five-second
think-time countdown, then the answer with the worked explanation and the app link. The question is chosen
by date from a fixed shuffle (no stored state, nothing repeats for months), exactly like the Telegram polls.

  python pipeline/shorts.py --slot 1 --out /tmp/short      render the video, upload when secrets exist
  python pipeline/shorts.py --slot 4 --lang en --dry-run   print the plan, render nothing

Six a day (slots 1..6, 07:00 to 22:00 IST); the language alternates and flips daily (--lang auto).

Upload needs three secrets (see docs/YOUTUBE.md): YT_CLIENT_ID, YT_CLIENT_SECRET, YT_REFRESH_TOKEN. Without
them the video is still rendered and the workflow keeps it as a downloadable file, so it can be uploaded by
hand. Rendering needs ffmpeg and Pillow built with raqm (Hindi conjuncts); without them the run ends with a
notice and exit 0, never a broken video.
"""
import argparse
import json
import os
import random
import subprocess
import sys
import textwrap
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import telegram_bot as tb  # noqa: E402

W, H = 1080, 1920
# Six Shorts a day, about three hours apart (IST). YouTube's default quota is 10,000 units a day and one upload
# costs 1,600, so six is the most that fits; an hourly schedule would be refused after the sixth.
SLOT_HOURS = [7, 10, 13, 16, 19, 22]
THINK_SECONDS = 5
QUESTION_SECONDS = 4
ANSWER_SECONDS = 9
CHANNEL = os.environ.get("TELEGRAM_URL") or "https://t.me/RailParikshaApp"
SITE = tb.SITE_URL
TITLE_MAX = 100
DESC_MAX = 4800
Q_MAX, OPT_MAX, EXPL_MAX = 230, 60, 420


def rotation(slot, day):
    """(slot number, language) for slot 1..6 of a day: the language alternates through the day and flips
    every day, so a given clock time is Hindi one day and English the next."""
    n = day.toordinal() * len(SLOT_HOURS) + slot - 1
    return n, "en" if (day.toordinal() + slot) % 2 else "hi"


def choose(slot, day, lang=None, pools=None):
    """The question for a slot and day, or None. Shorter text only: it has to fit a phone screen. Subjects follow
    the same cycle as the Telegram hourly quiz, and each subject walks its own fixed shuffle, so nothing repeats
    until the subject's whole pool has been used."""
    n, auto = rotation(slot, day)
    lang = lang or auto
    subject, step = tb.cycle_step(n)
    pool = (pools or {}).get(subject) if pools is not None else tb.load_pyq(subject, lang)
    pool = sorted((q for q in (pool or []) if fits(q, lang)), key=lambda r: r.get("id", ""))
    if not pool:
        return None
    random.Random(f"railpariksha-short-{lang}-{subject}").shuffle(pool)
    return pool[step % len(pool)]


def fits(q, lang="hi"):
    """Cheap length limits, then the real layout: the question, four options, the answer line, two lines of
    explanation and the three link lines must all fit on the 1920 px frame."""
    k = "en" if lang == "en" else "hi"
    if not (len(q["q_" + k]) <= Q_MAX and len(q["o_" + k]) == 4 and all(len(o) <= OPT_MAX for o in q["o_" + k])
            and len(q["e_" + k]) <= EXPL_MAX):
        return False
    return layout_end(q, lang) <= OPTIONS_END_MAX


OPTIONS_END_MAX = H - 330 - 90 - 2 * 66  # room below the options for the answer line, 2 explanation lines, links
_MEASURE = {}


def _estimate_lines(text, font, width):
    """Wrapped line count from cached per-character widths (cheap; the shaped text is never wider than the sum
    of its characters, so this errs towards more lines, never fewer)."""
    cache = _MEASURE.setdefault(id(font), {})

    def w(s):
        total = 0.0
        for c in s:
            if c not in cache:
                cache[c] = font.getlength(c)
            total += cache[c]
        return total

    space, lines, cur = w(" "), 1, 0.0
    for word in text.split():
        ww = w(word)
        if cur and cur + space + ww > width:
            lines, cur = lines + 1, ww
        else:
            cur = cur + space + ww if cur else ww
    return lines


def layout_end(q, lang):
    """The y at which the last option box ends in render_frames (estimated, slightly pessimistic)."""
    if "fonts" not in _MEASURE:
        _MEASURE["fonts"] = _fonts()
    fonts = _MEASURE["fonts"]
    k = "en" if lang == "en" else "hi"
    pad = 70
    y = 280 + 90 * _estimate_lines(q["q_" + k], fonts["big"], W - 2 * pad) + 40
    for opt in q["o_" + k]:
        y += max(110, 70 * _estimate_lines(opt, fonts["opt"], W - 2 * pad - 130) + 40) + 28
    return y


def title_for(q, lang="hi"):
    if lang == "en":
        head = tb.SUBJECT_EN.get(q.get("s"), "RRB")
        return tb.shorten(f"{head} PYQ: can you answer this? #Shorts #RRB #Railway", TITLE_MAX)
    head = tb.SUBJECT_HI.get(q.get("s"), "PYQ")
    return tb.shorten(f"{head} का PYQ: क्या आप सही उत्तर दे पाएँगे? #Shorts #RRB #Railway", TITLE_MAX)


def description_for(q, lang="hi"):
    label = tb.exam_label(q.get("pyq"))
    if lang == "en":
        return (
            f"A real previous-year railway exam question ({label}).\n\n"
            "We are students too. RailPariksha is made by students, for students: free, in Hindi and English.\n"
            f"Free app: {tb.PLAY_URL}\n"
            f"Website: {SITE}\n"
            f"Telegram (daily quizzes and current affairs): {CHANNEL}\n\n"
            "#RRBNTPC #RRBGroupD #RRBALP #RRBJE #RPF #Railway #PYQ #Shorts"
        )[:DESC_MAX]
    return (
        f"रेलवे परीक्षा का असली पिछले साल का प्रश्न ({label}).\n\n"
        "हम भी आपकी तरह स्टूडेंट्स हैं। RailPariksha स्टूडेंट्स ने स्टूडेंट्स के लिए बनाया है।\n"
        f"मुफ़्त ऐप: {tb.PLAY_URL}\n"
        f"वेबसाइट: {SITE}\n"
        f"Telegram (रोज़ के क्विज़ और करेंट अफेयर्स): {CHANNEL}\n\n"
        "#RRBNTPC #RRBGroupD #RRBALP #RRBJE #RPF #Railway #PYQ #Shorts"
    )[:DESC_MAX]


# ----------------------------------------------------------------------------------------------
# Frames
# ----------------------------------------------------------------------------------------------

def _fonts():
    from PIL import ImageFont
    f = tb.FONTS
    return {
        "big": ImageFont.truetype(str(f / "Mukta-ExtraBold.ttf"), 64),
        "opt": ImageFont.truetype(str(f / "Mukta-SemiBold.ttf"), 54),
        "small": ImageFont.truetype(str(f / "Mukta-Regular.ttf"), 40),
        "head": ImageFont.truetype(str(f / "Mukta-Bold.ttf"), 46),
        "count": ImageFont.truetype(str(f / "Mukta-ExtraBold.ttf"), 220),
        "expl": ImageFont.truetype(str(f / "Mukta-Regular.ttf"), 50),
    }


def _wrap(draw, text, font, width):
    """Greedy word wrap by measured pixel width (Devanagari has no fixed character width)."""
    lines, cur = [], ""
    for word in text.split():
        trial = f"{cur} {word}".strip()
        if draw.textlength(trial, font=font) <= width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def _background():
    from PIL import Image
    top, bottom = (10, 22, 51), (20, 38, 79)
    img = Image.new("RGB", (W, H), top)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    return img


def render_frames(q, out_dir, lang="hi"):
    """Writes PNG frames and returns [(path, seconds)] in play order."""
    from PIL import ImageDraw
    fonts = _fonts()
    k = "en" if lang == "en" else "hi"
    pad = 70
    labels = ["A", "B", "C", "D"]
    frames = []

    def base(reveal=None, countdown=None):
        img = _background()
        d = ImageDraw.Draw(img)
        d.text((pad, 90), "RailPariksha", font=fonts["head"], fill=(232, 186, 74))
        d.text((pad, 160), tb.exam_label(q.get("pyq")), font=fonts["small"], fill=(190, 210, 245))
        y = 280
        for line in _wrap(d, q["q_" + k].strip(), fonts["big"], W - 2 * pad):
            d.text((pad, y), line, font=fonts["big"], fill=(255, 255, 255))
            y += 90
        y += 40
        for i, opt in enumerate(q["o_" + k]):
            lines = _wrap(d, opt.strip(), fonts["opt"], W - 2 * pad - 130)
            h = max(110, 70 * len(lines) + 40)
            right = reveal == i
            fill = (28, 138, 78) if right else (255, 255, 255, 30) if reveal is None else (255, 255, 255, 18)
            box = (pad, y, W - pad, y + h)
            d.rounded_rectangle(box, radius=28, fill=fill if right else None,
                                outline=(232, 186, 74) if right else (120, 150, 210), width=4 if right else 3)
            d.text((pad + 34, y + h / 2 - 34), labels[i], font=fonts["opt"], fill=(232, 186, 74))
            ty = y + 20
            for line in lines:
                d.text((pad + 130, ty), line, font=fonts["opt"], fill=(255, 255, 255))
                ty += 70
            y += h + 28
        return img, d, y

    img, _, _ = base()
    p = out_dir / "q.png"
    img.save(p)
    frames.append((p, QUESTION_SECONDS))
    for n in range(THINK_SECONDS, 0, -1):
        img, d, y = base()
        d.text((W / 2 - 60, max(y + 20, 1380)), str(n), font=fonts["count"], fill=(232, 186, 74))
        p = out_dir / f"c{n}.png"
        img.save(p)
        frames.append((p, 1))
    img, d, y = base(reveal=q["a"])
    d.text((pad, y + 10), ("Correct answer: " if lang == "en" else "सही उत्तर: ") + labels[q["a"]],
           font=fonts["head"], fill=(160, 255, 190))
    y += 90
    room = max(1, (H - 330 - y) // 66)  # the three link lines below need the last 330 px
    lines = _wrap(d, tb.shorten(q["e_" + k], 360), fonts["expl"], W - 2 * pad)
    if len(lines) > room:
        lines = lines[:room]
        lines[-1] = lines[-1].rstrip(" ,;:.") + "…"
    for line in lines:
        d.text((pad, y), line, font=fonts["expl"], fill=(255, 255, 255))
        y += 66
    foot = ["Free app: RailPariksha on Google Play", f"Website: {SITE.split('//')[1]}",
            f"Telegram: {CHANNEL.split('//')[1]}"] if lang == "en" else \
        ["मुफ़्त ऐप: Google Play पर RailPariksha", f"वेबसाइट: {SITE.split('//')[1]}",
         f"Telegram: {CHANNEL.split('//')[1]}"]
    for i, line in enumerate(foot):
        d.text((pad, H - 270 + i * 60), line, font=fonts["small"], fill=(232, 186, 74))
    p = out_dir / "a.png"
    img.save(p)
    frames.append((p, ANSWER_SECONDS))
    return frames


def encode(frames, out_mp4):
    """H.264 + silent AAC (Shorts accepts silent, but some players want a track), 30 fps, yuv420p."""
    lst = out_mp4.with_suffix(".txt")
    lines = []
    for path, secs in frames:
        lines += [f"file '{path.resolve()}'", f"duration {secs}"]
    lines.append(f"file '{frames[-1][0].resolve()}'")
    lst.write_text("\n".join(lines), encoding="utf-8")
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(lst),
        "-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo", "-shortest",
        "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-preset", "medium", "-crf", "21",
        "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", str(out_mp4)], check=True)


# ----------------------------------------------------------------------------------------------
# Upload (YouTube Data API v3, resumable)
# ----------------------------------------------------------------------------------------------

def access_token():
    import requests
    r = requests.post("https://oauth2.googleapis.com/token", data={
        "client_id": os.environ["YT_CLIENT_ID"], "client_secret": os.environ["YT_CLIENT_SECRET"],
        "refresh_token": os.environ["YT_REFRESH_TOKEN"], "grant_type": "refresh_token"}, timeout=30)
    r.raise_for_status()
    return r.json()["access_token"]


def check(resp):
    """raise_for_status, but with Google's own reason (accessNotConfigured, quotaExceeded, ...) in the message."""
    if resp.ok:
        return
    try:
        err = resp.json()["error"]
        why = f"{err.get('status', '')} {err.get('message', '')} {[e.get('reason') for e in err.get('errors', [])]}"
    except Exception:  # noqa: BLE001
        why = resp.text[:300]
    raise RuntimeError(f"{resp.status_code} from {resp.url.split('?')[0]}: {why}")


def upload(mp4, title, description, lang="hi"):
    import requests
    token = access_token()
    meta = {
        "snippet": {"title": title, "description": description, "categoryId": "27",
                    "tags": ["RRB", "NTPC", "Group D", "Railway", "PYQ", "RPF"], "defaultLanguage": lang,
                    "defaultAudioLanguage": lang},
        "status": {"privacyStatus": "public", "selfDeclaredMadeForKids": False},
    }
    init = requests.post(
        "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=UTF-8",
                 "X-Upload-Content-Type": "video/mp4"}, data=json.dumps(meta), timeout=60)
    check(init)
    r = requests.put(init.headers["Location"], data=mp4.read_bytes(),
                     headers={"Content-Type": "video/mp4"}, timeout=600)
    check(r)
    return r.json().get("id")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slot", required=True, type=int, choices=range(1, len(SLOT_HOURS) + 1),
                    help="1..6 of the day, in order 07:00 10:00 13:00 16:00 19:00 22:00 IST")
    ap.add_argument("--lang", choices=["auto", "hi", "en"], default="auto")
    ap.add_argument("--out", default="short_out")
    ap.add_argument("--date", help="YYYY-MM-DD (default: today, IST)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    day = date.fromisoformat(args.date) if args.date else tb.today_ist()
    lang = rotation(args.slot, day)[1] if args.lang == "auto" else args.lang
    q = choose(args.slot, day, lang)
    if q is None:
        print("::notice::no suitable question for this slot today")
        return 0
    title, desc = title_for(q, lang), description_for(q, lang)
    print(f"[slot {args.slot} {lang}] {q.get('id')} | {title}")
    if args.dry_run:
        print(desc)
        return 0
    if not tb.card_available() or subprocess.run(["which", "ffmpeg"], capture_output=True).returncode != 0:
        print("::notice::needs ffmpeg and Pillow with raqm; no video made")
        return 0
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    mp4 = out / f"short_{day.isoformat()}_{args.slot}_{lang}.mp4"
    encode(render_frames(q, out, lang), mp4)
    (out / mp4.with_suffix(".txt.meta").name).write_text(f"{title}\n\n{desc}", encoding="utf-8")
    print(f"rendered {mp4} ({mp4.stat().st_size // 1024} KiB)")
    if all(os.environ.get(k) for k in ("YT_CLIENT_ID", "YT_CLIENT_SECRET", "YT_REFRESH_TOKEN")):
        try:
            print(f"uploaded: https://youtube.com/shorts/{upload(mp4, title, desc, lang)}")
        except Exception as e:  # noqa: BLE001
            print(f"::warning::upload failed ({e}); the video is kept as a workflow file")
    else:
        print("::notice::YouTube secrets not set; video kept as a workflow file only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
