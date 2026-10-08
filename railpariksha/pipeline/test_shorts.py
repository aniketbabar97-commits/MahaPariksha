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
        a, b = shorts.choose("morning", d), shorts.choose("morning", d)
        self.assertEqual(a["id"], b["id"])
        self.assertTrue(shorts.fits(a))
        self.assertEqual(len(a["o_hi"]), 4)

    def test_no_repeat_for_a_month(self):
        ids = [shorts.choose(s, date(2026, 10, 8) + timedelta(i))["id"] for s in shorts.SLOTS for i in range(30)]
        self.assertEqual(len(ids), len(set(ids)))

    def test_text_limits(self):
        q = shorts.choose("evening", date(2026, 10, 9))
        self.assertLessEqual(len(shorts.title_for(q)), shorts.TITLE_MAX)
        self.assertIn("#Shorts", shorts.title_for(q))
        self.assertIn("स्टूडेंट्स", shorts.description_for(q))

    @unittest.skipUnless(tb.card_available(), "needs Pillow with raqm")
    def test_frames_render(self):
        q = shorts.choose("morning", date(2026, 10, 8))
        with tempfile.TemporaryDirectory() as t:
            frames = shorts.render_frames(q, Path(t))
            self.assertEqual(len(frames), 2 + shorts.THINK_SECONDS)
            self.assertTrue(all(p.stat().st_size > 5000 for p, _ in frames))
            total = sum(s for _, s in frames)
            self.assertTrue(15 <= total <= 40, total)


if __name__ == "__main__":
    unittest.main()
