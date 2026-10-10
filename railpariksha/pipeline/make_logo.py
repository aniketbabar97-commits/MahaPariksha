#!/usr/bin/env python3
"""Builds every logo raster (launcher icons, splash, Play icon, website logos, store banners) from the one
source picture docs/brand/logo_source.jpg, recoloured to the brand navy. Run it after changing the source.

  pip install pillow numpy scipy
  python pipeline/make_logo.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/brand/logo_source.jpg"
RES = ROOT / "app/android/app/src/main/res"
SITE = ROOT / "docs/store/site_assets"
PLAY = ROOT / "docs/store/play_console_assets"
FONTS = ROOT / "app/assets/fonts"
SRC_NAVY = np.array([10, 30, 67], float)   # navy in the supplied picture
NAVY = (6, 30, 89)                          # brand navy, same as the native splash and adaptive-icon background
GOLD_SRC = np.array([230, 184, 76], float)
GOLD = (232, 186, 74)
CREAM = (255, 244, 214)


def recolour(img):
    """Only the colours change: navy -> brand navy (strongest on dark pixels, fading out towards white),
    gold -> brand gold (strongest on gold pixels)."""
    a = np.asarray(img.convert("RGB")).astype(float)
    mx = a.max(axis=2)
    navy_w = np.clip((215 - mx) / 150, 0, 1) * ((a[..., 2] >= a[..., 0]) & (a[..., 2] >= a[..., 1]))
    a += navy_w[..., None] * (np.array(NAVY, float) - SRC_NAVY)
    gold_like = (a[..., 0] - a[..., 2] > 60) & (a[..., 0] > 150)
    a[gold_like] += (np.array(GOLD, float) - GOLD_SRC)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def tile_of(full):
    """The rounded white-framed tile on a transparent background, cropped to its outer edge."""
    a = np.asarray(full).astype(int)
    frame = a.min(axis=2) > 150
    filled = ndi.binary_fill_holes(frame)
    filled = ndi.binary_opening(filled, iterations=3)
    ys, xs = np.nonzero(filled)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    alpha = Image.fromarray((ndi.gaussian_filter(filled.astype(float), 1.2) * 255).astype(np.uint8))
    out = full.convert("RGBA")
    out.putalpha(alpha)
    return out.crop(box)


def fit(img, size, pad=0.0, bg=None):
    """img scaled to size x size (contained, with pad fraction of margin) on bg (or transparent)."""
    s = size * 3 if size < 200 else size
    canvas = Image.new("RGBA", (s, s), (bg + (255,)) if bg else (0, 0, 0, 0))
    inner = round(s * (1 - 2 * pad))
    scale = inner / max(img.size)
    im = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(im, ((s - im.width) // 2, (s - im.height) // 2))
    return canvas if s == size else canvas.resize((size, size), Image.LANCZOS)


def save(img, path, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    (img.convert("RGB") if rgb else img).save(path, optimize=True)


def gradient(w, h):
    a, b = (6, 30, 89), (20, 50, 112)
    img = Image.new("RGB", (w, h), a)
    d = ImageDraw.Draw(img)
    for x in range(w):
        t = x / (w - 1)
        d.line([(x, 0), (x, h)], fill=tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)))
    return img


def banner(w, h, tile, tile_h, name_px, tag_px):
    img = gradient(w, h).convert("RGBA")
    t = tile.resize((round(tile.width * tile_h / tile.height), tile_h), Image.LANCZOS)
    img.alpha_composite(t, (round(w * 0.09), (h - t.height) // 2))
    d = ImageDraw.Draw(img)
    x = round(w * 0.09) + t.width + round(w * 0.05)
    avail = w - x - round(w * 0.05)
    while d.textlength("RailPariksha", font=ImageFont.truetype(str(FONTS / "Lora-Bold.ttf"), name_px)) > avail:
        name_px -= 2
    tag_px = min(tag_px, round(name_px * 0.36))
    name = ImageFont.truetype(str(FONTS / "Lora-Bold.ttf"), name_px)
    tag = ImageFont.truetype(str(FONTS / "Lora-Bold.ttf"), tag_px)
    cy = h // 2 + round(h * 0.03)
    d.text((x, cy - tag_px * 1.1), "RailPariksha", font=name, fill=CREAM, anchor="ls")
    d.text((x, cy + tag_px * 0.9), "RRB  •  RPF  EXAM  PREP", font=tag, fill=GOLD, anchor="ls")
    bar = d.textlength("RRB  •  RPF  EXAM  PREP", font=tag)
    d.rounded_rectangle((x, cy + tag_px * 1.6, x + bar, cy + tag_px * 1.6 + max(4, h // 90)), radius=4, fill=GOLD)
    return img.convert("RGB")


def youtube_banner(tile):
    """2048x1152; everything that matters sits in the 1235x338 safe area every device shows."""
    w, h = 2048, 1152
    img = gradient(w, h).convert("RGBA")
    d = ImageDraw.Draw(img)
    name = ImageFont.truetype(str(FONTS / "Lora-Bold.ttf"), 120)
    tag = ImageFont.truetype(str(FONTS / "Lora-Bold.ttf"), 44)
    line = "RRB  •  RPF  EXAM  PREP  •  FREE"
    t = tile.resize((round(tile.width * 260 / tile.height), 260), Image.LANCZOS)
    gap = 44
    text_w = max(d.textlength("RailPariksha", font=name), d.textlength(line, font=tag))
    x0 = round((w - (t.width + gap + text_w)) / 2)
    img.alpha_composite(t, (x0, (h - t.height) // 2))
    x = x0 + t.width + gap
    cy = h // 2
    d.text((x, cy + 10), "RailPariksha", font=name, fill=CREAM, anchor="ls")
    d.text((x, cy + 82), line, font=tag, fill=GOLD, anchor="ls")
    d.rounded_rectangle((x, cy + 104, x + d.textlength(line, font=tag), cy + 112), radius=4, fill=GOLD)
    return img.convert("RGB")


def main():
    full = recolour(Image.open(SRC))
    full.save(ROOT / "docs/brand/logo_recoloured_1024.png", optimize=True)
    tile = tile_of(full)
    # Android launcher: adaptive (tile inside the 66% safe zone, on the flat navy background) + legacy icon
    for d, fg, legacy in [("mdpi", 108, 48), ("hdpi", 162, 72), ("xhdpi", 216, 96), ("xxhdpi", 324, 144), ("xxxhdpi", 432, 192)]:
        save(fit(tile, fg, pad=0.19), RES / f"mipmap-{d}/ic_launcher_foreground.png")
        save(Image.new("RGBA", (fg, fg), NAVY + (255,)), RES / f"mipmap-{d}/ic_launcher_background.png")
        save(fit(tile, legacy, pad=0.0), RES / f"mipmap-{d}/ic_launcher.png")
    # splash: the tile on the native splash colour (Android 12 shows it inside a circle)
    for d, size in [("mdpi", 256), ("hdpi", 384), ("xhdpi", 512), ("xxhdpi", 768), ("xxxhdpi", 1024)]:
        for kind in ("drawable", "drawable-night"):
            save(fit(tile, size, pad=0.22), RES / f"{kind}-{d}/splash.png")
            save(fit(tile, size, pad=0.22), RES / f"{kind}-{d}/android12splash.png")
    save(fit(tile, 1024, pad=0.14), ROOT / "app/assets/splash_logo.png")
    # Play Store icon and website logos: the picture as supplied (tile on navy)
    save(full.resize((512, 512), Image.LANCZOS), PLAY / "icon_512x512.png", rgb=True)
    for size in (192, 512):
        save(full.resize((size, size), Image.LANCZOS), SITE / f"logo-{size}.png", rgb=True)
    save(full.resize((180, 180), Image.LANCZOS), SITE / "apple-touch-icon.png", rgb=True)
    for size in (96, 460):  # the tile alone on a transparent background, for the site header and hero (2x sizes)
        im = fit(tile, size, pad=0.0)
        im.save(SITE / f"logo-tile-{size}.webp", quality=88, method=6)
    save(fit(tile, 32, pad=0.0), SITE / "favicon-32.png")
    # /favicon.ico: browsers and crawlers ask for this path whatever the <link> says
    full.resize((48, 48), Image.LANCZOS).convert("RGBA").save(SITE / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    # store banners
    save(banner(1024, 500, tile, 330, 104, 40), PLAY / "feature_graphic_1024x500.png", rgb=True)
    save(banner(1200, 630, tile, 400, 118, 44), SITE / "og-image.png", rgb=True)
    yt = ROOT / "docs/store/youtube"
    save(youtube_banner(tile), yt / "banner_2048x1152.png", rgb=True)
    save(full.resize((800, 800), Image.LANCZOS), yt / "profile_800x800.png", rgb=True)
    print("done")


if __name__ == "__main__":
    main()
