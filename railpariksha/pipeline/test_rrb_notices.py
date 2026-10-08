"""Offline tests for rrb_notices.py: title extraction and the Telegram text (no network)."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rrb_notices as r  # noqa: E402

PAGE = ('<a href="/h">Home</a><a href="/a">Centralized Employment Notice CEN 01/2026 - Assistant Loco Pilot</a>'
        '<a href="/b">RRB NTPC CBT-2 Result declared for CEN 06/2025</a>'
        '<a href="/c">About Us and the history of the board</a><a href="/d">x</a>')


class Tests(unittest.TestCase):
    def test_titles(self):
        t = r.titles_from(PAGE)
        self.assertEqual(len(t), 2)
        self.assertTrue(all("About" not in x and x != "Home" for x in t))

    def test_ident_is_stable_and_source_specific(self):
        self.assertEqual(r.ident("A", "Result Declared"), r.ident("A", "result declared"))
        self.assertNotEqual(r.ident("A", "Result Declared"), r.ident("B", "Result Declared"))

    def test_text_has_no_dates_of_our_own_and_fits(self):
        new = [("RRB Apply", "RRB NTPC CBT-2 Result declared", "https://www.rrbapply.gov.in/")] * 9
        text = r.telegram_text(new)
        self.assertLessEqual(len(text), 4096)
        self.assertIn("आधिकारिक", text)
        self.assertIn("और 4 सूचनाएँ", text)


if __name__ == "__main__":
    unittest.main()
