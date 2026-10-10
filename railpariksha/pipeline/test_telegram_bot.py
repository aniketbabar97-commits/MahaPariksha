"""Offline tests for telegram_bot.py (no network, no token). Run: python pipeline/test_telegram_bot.py"""
import html.parser
import re
import sys
import unittest
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import telegram_bot as tb  # noqa: E402

DAY = date(2026, 10, 7)


class Tags(html.parser.HTMLParser):
    """Only the tags Telegram's HTML mode accepts from us may appear, and all must be closed."""

    def __init__(self):
        super().__init__()
        self.stack, self.bad = [], []

    def handle_starttag(self, tag, attrs):
        if tag not in ("b", "tg-spoiler"):
            self.bad.append(tag)
        self.stack.append(tag)

    def handle_endtag(self, tag):
        if not self.stack or self.stack.pop() != tag:
            self.bad.append("/" + tag)


def check_html(testcase, text):
    p = Tags()
    p.feed(text)
    testcase.assertEqual(p.bad, [], text[:120])
    testcase.assertEqual(p.stack, [], text[:120])
    testcase.assertLessEqual(len(text), tb.MESSAGE_MAX)


def check_poll(testcase, p):
    testcase.assertLessEqual(len(p["question"]), tb.POLL_QUESTION_MAX)
    testcase.assertTrue(2 <= len(p["options"]) <= 10)
    testcase.assertTrue(all(0 < len(o) <= tb.POLL_OPTION_MAX for o in p["options"]))
    testcase.assertEqual(len(set(p["options"])), len(p["options"]))
    testcase.assertTrue(0 <= p["correct_option_id"] < len(p["options"]))
    testcase.assertTrue(0 < len(p["explanation"]) <= tb.POLL_EXPLANATION_MAX)
    testcase.assertEqual(p["type"], "quiz")
    testcase.assertTrue(re.search(r"[ऀ-ॿ]", p["question"]))


class Content(unittest.TestCase):
    def test_shorten(self):
        self.assertEqual(tb.shorten("छोटा वाक्य।", 50), "छोटा वाक्य।")
        long = "पहला वाक्य यहाँ है। " + "दूसरा बहुत लंबा वाक्य " * 30
        out = tb.shorten(long, 40)
        self.assertLessEqual(len(out), 40)
        self.assertTrue(out.endswith("है।"), out)
        words = tb.shorten("शब्द " * 100, 40)
        self.assertLessEqual(len(words), 40)

    def test_poll_ok_rejects_unsuitable(self):
        good = dict(q_hi="भारत की राजधानी क्या है?", o_hi=["दिल्ली", "मुंबई", "चेन्नई", "कोलकाता"], a=0,
                    e_hi="नई दिल्ली भारत की राजधानी है।", e_en="New Delhi is the capital.")
        self.assertTrue(tb.poll_ok(good))
        self.assertFalse(tb.poll_ok({**good, "q_hi": "दिए गए चित्र में कितने त्रिभुज हैं?"}))
        self.assertFalse(tb.poll_ok({**good, "e_hi": "सही उत्तर: दिल्ली (आधिकारिक उत्तर कुंजी)।"}))
        self.assertFalse(tb.poll_ok({**good, "o_hi": ["x" * 101, "b", "c", "d"]}))
        self.assertFalse(tb.poll_ok({**good, "o_hi": ["a", "a", "c", "d"]}))
        self.assertFalse(tb.poll_ok({**good, "a": 9}))
        self.assertFalse(tb.poll_ok({**good, "q_hi": "x" * 300}))
        self.assertFalse(tb.poll_ok({**good, "q_hi": "What is the capital of India?"}))

    def test_every_poll_slot_is_valid_for_four_months(self):
        for i in range(120):
            day = DAY + timedelta(days=i)
            for slot in tb.POLL_SLOTS:
                p = tb.poll_for(slot, day, "@chat")
                self.assertIsNotNone(p, (slot, day))
                check_poll(self, p)

    def test_rotation_is_deterministic_and_moves(self):
        a = tb.poll_for("poll_morning", DAY, "@c")
        self.assertEqual(a, tb.poll_for("poll_morning", DAY, "@c"))
        seen = {tb.poll_for("poll_morning", DAY + timedelta(days=i), "@c")["question"] for i in range(30)}
        self.assertGreaterEqual(len(seen), 28)
        # Three polls on one day are three different questions.
        day_polls = {tb.poll_for(s, DAY, "@c")["question"] for s in tb.POLL_SLOTS}
        self.assertEqual(len(day_polls), 3)

    def test_hourly_quiz_alternates_language_and_never_repeats(self):
        from datetime import datetime, timedelta
        seen, langs = set(), set()
        for i in range(30):
            for h in range(6, 24):
                n, lang = tb.rotation(datetime(2026, 10, 1, h, tzinfo=tb.IST) + timedelta(days=i))
                p = tb.quiz_for(n, lang, "c")
                self.assertTrue(p and len(p["question"]) <= tb.POLL_QUESTION_MAX)
                self.assertEqual(len(p["options"]), 4)
                self.assertLessEqual(len(p["explanation"]), tb.POLL_EXPLANATION_MAX)
                if lang == "hi":
                    self.assertTrue(re.search(r"[ऀ-ॿ]", p["question"]))
                else:
                    self.assertTrue(re.search(r"[A-Za-z]{3}", p["question"]))
                    self.assertFalse(re.search(r"[ऀ-ॿ]", p["question"] + "".join(p["options"])))
                seen.add((lang, p["question"]))
        self.assertEqual(len(seen), 30 * 18)
        # the same clock hour is Hindi one day and English the next
        a = tb.rotation(datetime(2026, 10, 1, 9, tzinfo=tb.IST))[1]
        b = tb.rotation(datetime(2026, 10, 2, 9, tzinfo=tb.IST))[1]
        self.assertNotEqual(a, b)
        # consecutive hours alternate
        self.assertNotEqual(tb.rotation(datetime(2026, 10, 1, 9, tzinfo=tb.IST))[1],
                            tb.rotation(datetime(2026, 10, 1, 10, tzinfo=tb.IST))[1])

    def test_text_posts_are_valid_html_and_within_limits(self):
        for i in range(60):
            day = DAY + timedelta(days=i)
            check_html(self, tb.fact_text(day))
            check_html(self, tb.tip_text(day))
        self.assertIn("राष्ट्रीय युवा दिवस", tb.tip_text(date(2026, 1, 12)))
        self.assertGreaterEqual(len(tb.special_day(date(2026, 1, 12))), 1)

    def test_fact_alternates_card_types(self):
        kinds = {("चीट शीट" in tb.fact_text(DAY + timedelta(days=i))) for i in range(6)}
        self.assertEqual(kinds, {True, False})
        self.assertIn("<tg-spoiler>", "".join(tb.fact_text(DAY + timedelta(days=i)) for i in range(6)))

    def test_ca_digest(self):
        by = tb.feed_days()
        newest = max(by)
        qs = tb.distinct_stories(by[newest])
        self.assertTrue(qs)
        d = date.fromisoformat(newest)
        cap = tb.ca_caption(d, qs)
        self.assertLessEqual(len(cap), tb.CAPTION_MAX)
        check_html(self, cap)
        check_html(self, tb.ca_text(d, qs))
        # No story appears twice.
        heads = [tb.fact_of_headline(q) for q in qs]
        self.assertEqual(len(heads), len(set(heads)))

    def test_weekly_recap(self):
        by = tb.feed_days()
        newest = date.fromisoformat(max(by))
        text = tb.weekly_text(newest)
        self.assertTrue(text)
        check_html(self, text)

    @unittest.skipUnless(tb.card_available(), "Pillow without raqm: the card is skipped in production too")
    def test_card_png(self):
        by = tb.feed_days()
        newest = max(by)
        png = tb.make_card(date.fromisoformat(newest), tb.distinct_stories(by[newest]))
        self.assertTrue(png.startswith(b"\x89PNG"))
        self.assertGreater(len(png), 20_000)


class Slots(unittest.TestCase):
    def test_every_slot_dry_runs(self):
        by = tb.feed_days()
        fresh = date.fromisoformat(max(by))
        bot = tb.Bot("t", "@c", dry_run=True)
        for slot in tb.SLOTS:
            if slot == "announce":
                tb.run_slot(bot, slot, fresh, text="सूचना <b>test</b>")
            else:
                tb.run_slot(bot, slot, fresh)

    def test_stale_feed_is_not_posted(self):
        by = tb.feed_days()
        stale = date.fromisoformat(max(by)) + timedelta(days=5)
        bot = tb.Bot("t", "@c", dry_run=True)
        tb.run_slot(bot, "ca", stale)
        self.assertEqual(bot.sent, 0)

    def test_token_is_never_printed(self):
        import io
        from contextlib import redirect_stdout
        buf = io.StringIO()
        with redirect_stdout(buf):
            tb.run_slot(tb.Bot("123456:SECRETTOKEN", "@c", dry_run=True), "poll_noon", DAY)
        self.assertNotIn("SECRETTOKEN", buf.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=1)
