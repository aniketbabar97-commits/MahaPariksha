#!/usr/bin/env python3
"""Frames the raw screen renders into the seven Play Store screenshots (1080x1920) and the website strip.

  STORE_SHOTS_DIR=/tmp/raw flutter test test/store_shots_test.dart     (in app/)   renders the real screens
  python pipeline/store_shots.py --raw /tmp/raw                                     frames them

Writes docs/store/play_console_assets/screenshots/N_*.png and docs/store/site_assets/shot-N.webp.
Needs Pillow built with raqm (Hindi conjuncts).
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "app/assets/fonts"
OUT = ROOT / "docs/store/play_console_assets/screenshots"
SITE = ROOT / "docs/store/site_assets"
W, H = 1080, 1920
TOP, BOTTOM = (10, 22, 51), (20, 38, 79)
GOLD = (232, 186, 74)
SHOTS = [  # raw name, output name, Hindi caption, English caption
    ("today", "1_01_today", "रोज़ का मिशन, स्ट्रीक और करेंट अफेयर्स", "Daily mission, streak & current affairs"),
    ("pyq", "2_02_pyq", "रेलवे के असली पिछले साल के प्रश्न", "Real previous-year railway papers"),
    ("quiz", "3_04_quiz_explanation", "हर उत्तर की आसान व्याख्या", "Every answer explained simply"),
    ("ca", "4_05_ca_digest", "रोज़ का करेंट अफेयर्स", "Daily current affairs, in short"),
    ("flashcards", "5_07_flashcards", "फ्लैशकार्ड से तेज़ रिवीज़न", "Quick revision with flashcards"),
    ("mock", "6_09_mock", "असली परीक्षा जैसे मॉक टेस्ट", "Mock tests like the real exam"),
    ("practice", "7_03_practice", "विषयवार अभ्यास", "Practice subject by subject"),
]


def gradient():
    img = Image.new("RGB", (W, H), TOP)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(int(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return img


def fit(draw, text, path, size, width):
    while size > 40:
        font = ImageFont.truetype(str(path), size)
        if draw.textlength(text, font=font) <= width:
            return font
        size -= 2
    return ImageFont.truetype(str(path), size)


def frame(raw, hi, en):
    img = gradient()
    d = ImageDraw.Draw(img)
    f = fit(d, hi, FONTS / "Mukta-ExtraBold.ttf", 84, W - 120)
    d.text((W / 2, 150), hi, font=f, fill=(255, 255, 255), anchor="mm")
    f2 = fit(d, en, FONTS / "Lora-Bold.ttf", 42, W - 160)
    d.text((W / 2, 245), en, font=f2, fill=GOLD, anchor="mm")
    # phone: dark body with the screen inset, cropped from the bottom so the top of the app is always visible
    x0, y0, x1, y1 = 100, 330, 980, 1850
    d.rounded_rectangle((x0, y0, x1, y1), radius=84, fill=(6, 12, 28), outline=(40, 56, 98), width=3)
    pad = 24
    sw, sh = x1 - x0 - 2 * pad, y1 - y0 - 2 * pad
    shot = Image.open(raw).convert("RGB")
    scale = sw / shot.width
    shot = shot.resize((sw, round(shot.height * scale)), Image.LANCZOS).crop((0, 0, sw, sh))
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), radius=62, fill=255)
    img.paste(shot, (x0 + pad, y0 + pad), mask)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, help="folder with today.png, pyq.png, ... from the screen render")
    args = ap.parse_args()
    raw = Path(args.raw)
    for n, (name, out, hi, en) in enumerate(SHOTS, 1):
        src = raw / f"{name}.png"
        if not src.exists():
            sys.exit(f"missing {src}")
        img = frame(src, hi, en)
        img.save(OUT / f"{out}.png", optimize=True)
        img.resize((360, 640), Image.LANCZOS).save(SITE / f"shot-{n}.webp", quality=82, method=6)
        print("wrote", out)


if __name__ == "__main__":
    main()
