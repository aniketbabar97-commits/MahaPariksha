#!/usr/bin/env python3
"""YouTube Shorts for RailPariksha, built from the same previous-year questions as the Telegram quizzes.

One vertical (1080x1920) video of about 20 seconds per run: the question and four options, a five-second
think-time countdown, then the answer with the worked explanation and the app link. The question is chosen
by date from a fixed shuffle (no stored state, nothing repeats for months), exactly like the Telegram polls.

  python pipeline/shorts.py --slot morning --out /tmp/short      render the video, upload when secrets exist
  python pipeline/shorts.py --slot evening --dry-run              print the plan, render nothing

Upload needs three secrets (see docs/YOUTUBE.md): YT_CLIENT_ID, YT_CLIENT_SECRET, YT_REFRESH_TOKEN. Without
them the video is still rendered and the workflow keeps it as a downloadable file, so it can be uploaded by
hand. Rendering needs ffmpeg and Pillow built with raqm (Hindi conjuncts); without them the run ends with a
notice and exit 0, never a broken video.
"""
import argparse
import json
import os
import subprocess
import sys
import textwrap
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import telegram_bot as tb  # noqa: E402

W, H = 1080, 1920
SLOTS = {"morning": ("poll_morning", 0), "evening": ("poll_evening", 3)}
THINK_SECONDS = 5
QUESTION_SECONDS = 4
ANSWER_SECONDS = 9
CHANNEL = os.environ.get("TELEGRAM_URL") or "https://t.me/RailParikshaApp"
TITLE_MAX = 100
DESC_MAX = 4800


def choose(slot, day, pools=None):
    """The question for a slot and day, or None. Shorter text only: it has to fit a phone screen."""
    n, subjects = tb.POLL_SLOTS[SLOTS[slot][0]]
    subject = subjects[day.weekday()]
    pool = (pools or {}).get(subject) if pools is not None else tb.load_pyq(subject)
    pool = [q for q in (pool or []) if fits(q)]
    return tb.pick(pool, "short-" + subject, day, offset=n * 7 + SLOTS[slot][1])


def fits(q):
    return len(q["q_hi"]) <= 230 and all(len(o) <= 60 for o in q["o_hi"]) and len(q["o_hi"]) == 4 \
        and len(q["e_hi"]) <= 420


def title_for(q):
    head = tb.SUBJECT_HI.get(q.get("s"), "PYQ")
    return tb.shorten(f"{head} का PYQ: क्या आप सही उत्तर दे पाएँगे? #Shorts #RRB #Railway", TITLE_MAX)


def description_for(q):
    label = tb.exam_label(q.get("pyq"))
    return (
        f"रेलवे परीक्षा का असली पिछले साल का प्रश्न ({label}).\n\n"
        "हम भी आपकी तरह स्टूडेंट्स हैं। RailPariksha स्टूडेंट्स ने स्टूडेंट्स के लिए बनाया है।\n"
        f"📲 मुफ़्त ऐप: {tb.PLAY_URL}\n"
        f"💬 रोज़ के क्विज़ और करेंट अफेयर्स: {CHANNEL}\n\n"
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
    top, bottom = (11, 61, 145), (6, 32, 84)
    img = Image.new("RGB", (W, H), top)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row
    return img


def render_frames(q, out_dir):
    """Writes PNG frames and returns [(path, seconds)] in play order."""
    from PIL import ImageDraw
    fonts = _fonts()
    pad = 70
    labels = ["A", "B", "C", "D"]
    frames = []

    def base(reveal=None, countdown=None):
        img = _background()
        d = ImageDraw.Draw(img)
        d.text((pad, 90), "RailPariksha", font=fonts["head"], fill=(255, 214, 102))
        d.text((pad, 160), tb.exam_label(q.get("pyq")), font=fonts["small"], fill=(190, 210, 245))
        y = 280
        for line in _wrap(d, q["q_hi"].strip(), fonts["big"], W - 2 * pad):
            d.text((pad, y), line, font=fonts["big"], fill=(255, 255, 255))
            y += 90
        y += 40
        for i, opt in enumerate(q["o_hi"]):
            lines = _wrap(d, opt.strip(), fonts["opt"], W - 2 * pad - 130)
            h = max(110, 70 * len(lines) + 40)
            right = reveal == i
            fill = (28, 138, 78) if right else (255, 255, 255, 30) if reveal is None else (255, 255, 255, 18)
            box = (pad, y, W - pad, y + h)
            d.rounded_rectangle(box, radius=28, fill=fill if right else None,
                                outline=(255, 214, 102) if right else (120, 150, 210), width=4 if right else 3)
            d.text((pad + 34, y + h / 2 - 34), labels[i], font=fonts["opt"], fill=(255, 214, 102))
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
        d.text((W / 2 - 60, max(y + 20, 1380)), str(n), font=fonts["count"], fill=(255, 214, 102))
        p = out_dir / f"c{n}.png"
        img.save(p)
        frames.append((p, 1))
    img, d, y = base(reveal=q["a"])
    d.text((pad, y + 10), "सही उत्तर: " + labels[q["a"]], font=fonts["head"], fill=(160, 255, 190))
    y += 90
    for line in _wrap(d, tb.shorten(q["e_hi"], 360), fonts["expl"], W - 2 * pad)[:6]:
        d.text((pad, y), line, font=fonts["expl"], fill=(255, 255, 255))
        y += 66
    d.text((pad, H - 170), "मुफ़्त ऐप + रोज़ के क्विज़: Telegram @RailParikshaApp", font=fonts["small"], fill=(255, 214, 102))
    d.text((pad, H - 110), "स्टूडेंट्स द्वारा, स्टूडेंट्स के लिए", font=fonts["small"], fill=(190, 210, 245))
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


def upload(mp4, title, description):
    import requests
    token = access_token()
    meta = {
        "snippet": {"title": title, "description": description, "categoryId": "27",
                    "tags": ["RRB", "NTPC", "Group D", "Railway", "PYQ", "RPF"], "defaultLanguage": "hi"},
        "status": {"privacyStatus": "public", "selfDeclaredMadeForKids": False},
    }
    init = requests.post(
        "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=UTF-8",
                 "X-Upload-Content-Type": "video/mp4"}, data=json.dumps(meta), timeout=60)
    init.raise_for_status()
    r = requests.put(init.headers["Location"], data=mp4.read_bytes(),
                     headers={"Content-Type": "video/mp4"}, timeout=600)
    r.raise_for_status()
    return r.json().get("id")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slot", required=True, choices=list(SLOTS))
    ap.add_argument("--out", default="short_out")
    ap.add_argument("--date", help="YYYY-MM-DD (default: today, IST)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    day = date.fromisoformat(args.date) if args.date else tb.today_ist()
    q = choose(args.slot, day)
    if q is None:
        print("::notice::no suitable question for this slot today")
        return 0
    title, desc = title_for(q), description_for(q)
    print(f"[{args.slot}] {q.get('id')} | {title}")
    if args.dry_run:
        print(desc)
        return 0
    if not tb.card_available() or subprocess.run(["which", "ffmpeg"], capture_output=True).returncode != 0:
        print("::notice::needs ffmpeg and Pillow with raqm; no video made")
        return 0
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    mp4 = out / f"short_{day.isoformat()}_{args.slot}.mp4"
    encode(render_frames(q, out), mp4)
    (out / mp4.with_suffix(".txt.meta").name).write_text(f"{title}\n\n{desc}", encoding="utf-8")
    print(f"rendered {mp4} ({mp4.stat().st_size // 1024} KiB)")
    if all(os.environ.get(k) for k in ("YT_CLIENT_ID", "YT_CLIENT_SECRET", "YT_REFRESH_TOKEN")):
        try:
            print(f"uploaded: https://youtube.com/shorts/{upload(mp4, title, desc)}")
        except Exception as e:  # noqa: BLE001
            print(f"::warning::upload failed ({e}); the video is kept as a workflow file")
    else:
        print("::notice::YouTube secrets not set; video kept as a workflow file only")
    return 0


if __name__ == "__main__":
    sys.exit(main())
