"""Offline tests for shorts.py (no network, no ffmpeg)."""
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import shorts  # noqa: E402
import telegram_bot as tb  # noqa: E402


class ShortsTests(unittest.TestCase):
    def test_choice_is_stable_and_fits(self):
        d = date(2026, 10, 8)
        for lang in ("hi", "en"):
            a, b = shorts.choose(1, d, lang), shorts.choose(1, d, lang)
            self.assertEqual(a["id"], b["id"])
            self.assertTrue(shorts.fits(a, lang))
            self.assertEqual(len(a["o_" + lang]), 4)

    def test_language_alternates_and_flips_daily(self):
        d = date(2026, 10, 8)
        langs = [shorts.rotation(s, d)[1] for s in range(1, 7)]
        self.assertEqual(langs, ["en", "hi"] * 3 if langs[0] == "en" else ["hi", "en"] * 3)
        for s in range(1, 7):
            self.assertNotEqual(shorts.rotation(s, d)[1], shorts.rotation(s, d + timedelta(1))[1])

    def test_no_repeat_in_a_language_for_a_month(self):
        """The same question can come back in the other language, but never twice in the same one."""
        ids = []
        for i in range(30):
            for s in range(1, 7):
                d = date(2026, 10, 8) + timedelta(i)
                lang = shorts.rotation(s, d)[1]
                ids.append((lang, shorts.choose(s, d)["id"]))
        self.assertEqual(len(ids), len(set(ids)))

    def test_text_limits_and_links(self):
        q = shorts.choose(4, date(2026, 10, 9), "en")
        for lang in ("hi", "en"):
            self.assertLessEqual(len(shorts.title_for(q, lang)), shorts.TITLE_MAX)
            self.assertIn("PYQ", shorts.title_for(q, lang))
            self.assertNotIn("#", shorts.title_for(q, lang))  # hashtags live in the description
            self.assertLessEqual(len(shorts.hashtags_for(q).split()), 5)
            self.assertIn("#Shorts", shorts.hashtags_for(q))
            self.assertLessEqual(sum(len(t) + 1 for t in shorts.tags_for(q, lang)), 500)
            desc = shorts.description_for(q, lang)
            for link in (tb.PLAY_URL, tb.SITE_URL, shorts.CHANNEL):
                self.assertIn(link, desc)
        self.assertIn("स्टूडेंट्स", shorts.description_for(q, "hi"))

    @unittest.skipUnless(tb.card_available(), "needs Pillow with raqm")
    def test_frames_render(self):
        for lang in ("hi", "en"):
            q = shorts.choose(1, date(2026, 10, 8), lang)
            with tempfile.TemporaryDirectory() as t:
                frames = shorts.render_frames(q, Path(t), lang)
                self.assertEqual(len(frames), 2 + shorts.THINK_SECONDS)
                self.assertTrue(all(p.stat().st_size > 5000 for p, _ in frames))
                total = sum(s for _, s in frames)
                self.assertTrue(15 <= total <= 40, total)

    @unittest.skipUnless(tb.card_available(), "needs Pillow with raqm")
    def test_layout_estimate_is_never_below_the_real_wrap(self):
        """fits() relies on an estimate of the wrapped height; it must not be lower than what is drawn."""
        import random
        from PIL import Image, ImageDraw
        d, f = ImageDraw.Draw(Image.new("RGB", (shorts.W, shorts.H))), shorts._fonts()
        for lang in ("hi", "en"):
            pool = tb.load_pyq("gk", lang)
            for q in random.Random(7).sample(pool, 60):
                y = 280 + 90 * len(shorts._wrap(d, q["q_" + lang].strip(), f["big"], shorts.W - 140)) + 40
                for o in q["o_" + lang]:
                    y += max(110, 70 * len(shorts._wrap(d, o.strip(), f["opt"], shorts.W - 270)) + 40) + 28
                self.assertGreaterEqual(shorts.layout_end(q, lang), y)


if __name__ == "__main__":
    unittest.main()
