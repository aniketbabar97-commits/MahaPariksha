"""Offline test: the website builds, includes previous-year pages, and shows no ads until AdSense is configured."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent


class SiteTests(unittest.TestCase):
    def test_build(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("ADSENSE")}
        with tempfile.TemporaryDirectory() as t:
            r = subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t, "--base-url", "https://example.org"],
                               capture_output=True, text=True, env=env)
            self.assertEqual(r.returncode, 0, r.stderr)
            files = list(Path(t).glob("*.html"))
            self.assertGreater(len(files), 1000)
            pyq = [f for f in files if f.name.startswith("pyq-")]
            self.assertGreater(len(pyq), 500)
            self.assertTrue((Path(t) / "sitemap.xml").exists())
            for f in pyq[:50]:
                self.assertNotIn("adsbygoogle", f.read_text(encoding="utf-8"))
            home = (Path(t) / "index.html").read_text(encoding="utf-8")
            self.assertIn("pyq-rrb_ntpc.html".replace("_", "_"), home.replace("pyq-rrb_ntpc", "pyq-rrb_ntpc"))

    def test_ads_only_when_configured(self):
        env = dict(os.environ, ADSENSE_CLIENT="ca-pub-1", ADSENSE_SLOT="2")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t, "--base-url", "https://example.org"],
                           check=True, capture_output=True, env=env)
            f = next(Path(t).glob("pyq-rrb-ntpc*.html"))
            self.assertIn("adsbygoogle", f.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
