"""Turns the newest day of content/ca_feed.json into ready-to-post text: a Telegram/WhatsApp message
(Hindi, with the app link) and a 60-second YouTube Shorts script. Optionally posts the message to a
Telegram channel when TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are set (the daily workflow does this).

  python pipeline/ca_post.py                 # print both texts
  python pipeline/ca_post.py --out dir       # also write telegram.txt / shorts.txt there
  python pipeline/ca_post.py --telegram      # post to Telegram (needs the two env vars)
"""
import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEED = ROOT / "content/ca_feed.json"
PLAY_URL = "https://play.google.com/store/apps/details?id=app.railpariksha"
MONTHS_HI = ["जनवरी", "फ़रवरी", "मार्च", "अप्रैल", "मई", "जून", "जुलाई", "अगस्त", "सितंबर", "अक्टूबर", "नवंबर", "दिसंबर"]


def newest_day():
    qs = json.loads(FEED.read_text(encoding="utf-8"))["questions"]
    if not qs:
        return None, []
    day = max(q["date"] for q in qs)
    return day, [q for q in qs if q["date"] == day]


def hindi_date(iso):
    d = date.fromisoformat(iso)
    return f"{d.day} {MONTHS_HI[d.month - 1]} {d.year}"


def telegram_text(day, qs):
    lines = [f"📰 *आज का करेंट अफेयर्स — {hindi_date(day)}*", "रेलवे परीक्षा (RRB NTPC, Group D, ALP, RPF) के लिए ज़रूरी बातें:", ""]
    for i, q in enumerate(qs, 1):
        # One line per story: the fact itself, not the question, so the post reads as a brief.
        lines.append(f"{i}. {q['e_hi'].split('।')[0].strip()}।")
    lines += ["", "❓ *आज का सवाल:*", qs[0]["q_hi"]]
    for letter, opt in zip("ABCD", qs[0]["o_hi"]):
        lines.append(f"{letter}. {opt}")
    lines += ["", "जवाब और पूरी क्विज़ ऐप में 👇", PLAY_URL, "", "#RRB #RailwayExam #CurrentAffairs #RailPariksha"]
    return "\n".join(lines)


def shorts_script(day, qs):
    picks = qs[:5]
    lines = [f"# YouTube Short — करेंट अफेयर्स {hindi_date(day)} (≈60 s)", "",
             "[0–3 s] HOOK (text on screen + voice): \"रेलवे परीक्षा के लिए आज की 5 ज़रूरी खबरें — 60 सेकंड में!\"", ""]
    t = 3
    for i, q in enumerate(picks, 1):
        fact = q["e_hi"].split("।")[0].strip()
        lines.append(f"[{t}–{t + 10} s] #{i}: {fact}।")
        lines.append(f"       (on screen: {q['o_hi'][q['a']]})")
        t += 10
    lines += ["", f"[{t}–{t + 5} s] CTA: \"रोज़ ऐसे ही 5 खबरें और 45,000+ PYQ — RailPariksha ऐप, लिंक डिस्क्रिप्शन में।\"", "",
              "Description:", f"आज का करेंट अफेयर्स {hindi_date(day)} | RRB NTPC, Group D, ALP, RPF | RailPariksha ऐप: {PLAY_URL}",
              "#RRB #RailwayExam #CurrentAffairs #NTPC #GroupD #RPF"]
    return "\n".join(lines)


def post_telegram(text):
    token, chat = os.environ.get("TELEGRAM_BOT_TOKEN"), os.environ.get("TELEGRAM_CHAT_ID")
    if not token or not chat:
        print("TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID not set; not posting", file=sys.stderr)
        return False
    data = urllib.parse.urlencode({"chat_id": chat, "text": text, "parse_mode": "Markdown",
                                   "disable_web_page_preview": "false"}).encode()
    req = urllib.request.Request(f"https://api.telegram.org/bot{token}/sendMessage", data=data)
    with urllib.request.urlopen(req, timeout=30) as r:
        ok = json.loads(r.read()).get("ok", False)
    print("posted to Telegram" if ok else "Telegram refused the post", file=sys.stderr)
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out")
    ap.add_argument("--telegram", action="store_true")
    args = ap.parse_args()
    day, qs = newest_day()
    if not qs:
        print("feed is empty; nothing to post")
        return 0
    tg, sh = telegram_text(day, qs), shorts_script(day, qs)
    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        (out / "telegram.txt").write_text(tg, encoding="utf-8")
        (out / "shorts.txt").write_text(sh, encoding="utf-8")
        print(f"wrote {out}/telegram.txt and shorts.txt for {day}")
    else:
        print(tg, "\n\n" + "=" * 60 + "\n", sh, sep="\n")
    if args.telegram:
        post_telegram(tg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
