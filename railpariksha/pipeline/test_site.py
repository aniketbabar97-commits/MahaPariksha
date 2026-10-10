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
            self.assertIn("pub-9100209280220037", (Path(t) / "app-ads.txt").read_text(encoding="utf-8"))
            for f in pyq[:50]:
                self.assertNotIn("adsbygoogle", f.read_text(encoding="utf-8"))
            home = (Path(t) / "index.html").read_text(encoding="utf-8")
            self.assertIn("pyq-rrb_ntpc", home)

    def test_preview_address_never_becomes_canonical(self):
        """A workers.dev / pages.dev SITE_URL (the Cloudflare preview address) falls back to the production domain."""
        env = dict(os.environ, SITE_URL="https://railpariksha.example.workers.dev")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t],
                           check=True, capture_output=True, env=env)
            home = (Path(t) / "index.html").read_text(encoding="utf-8")
            self.assertIn('rel="canonical" href="https://railpariksha.in/"', home)
            self.assertNotIn("workers.dev", (Path(t) / "sitemap.xml").read_text(encoding="utf-8"))
            self.assertNotIn("workers.dev", (Path(t) / "robots.txt").read_text(encoding="utf-8"))

    def test_clean_urls_for_cloudflare(self):
        env = dict(os.environ, SITE_URL="https://example.org")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t],
                           check=True, capture_output=True, env=env)
            home = (Path(t) / "index.html").read_text(encoding="utf-8")
            self.assertIn('rel="canonical" href="https://example.org/"', home)
            sm = (Path(t) / "sitemap.xml").read_text(encoding="utf-8")
            self.assertNotIn(".html", sm)
            self.assertIn("/privacy</loc>", sm)
            page = next(Path(t).glob("pyq-rrb-ntpc*.html")).read_text(encoding="utf-8")
            self.assertNotIn('.html"', page)

    def test_clean_urls_on_a_custom_domain(self):
        """Cloudflare redirects /x.html to /x on a bought domain too, so canonicals and the sitemap stay extension-less."""
        env = dict(os.environ, SITE_URL="https://railpariksha.in")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t],
                           check=True, capture_output=True, env=env)
            home = (Path(t) / "index.html").read_text(encoding="utf-8")
            self.assertIn('rel="canonical" href="https://railpariksha.in/"', home)
            sm = (Path(t) / "sitemap.xml").read_text(encoding="utf-8")
            self.assertNotIn(".html", sm)
            self.assertIn("https://railpariksha.in/privacy</loc>", sm)
            self.assertIn("sitemap.xml", (Path(t) / "robots.txt").read_text(encoding="utf-8"))

    def test_two_languages_two_addresses(self):
        """Hindi at /x, English at /en/x: own language, canonical, hreflang, switch link, sitemap alternates."""
        import re
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t, "--base-url", "https://example.org"],
                           check=True, capture_output=True)
            out = Path(t)
            hi = (out / "index.html").read_text(encoding="utf-8")
            en = (out / "en" / "index.html").read_text(encoding="utf-8")
            self.assertIn('<html lang="hi">', hi)
            self.assertIn('<html lang="en">', en)
            self.assertIn('rel="canonical" href="https://example.org/"', hi)
            self.assertIn('rel="canonical" href="https://example.org/en/"', en)
            for page in (hi, en):
                self.assertIn('hreflang="hi" href="https://example.org/"', page)
                self.assertIn('hreflang="en" href="https://example.org/en/"', page)
                self.assertIn('hreflang="x-default" href="https://example.org/"', page)
                self.assertNotIn("@@", page)
                self.assertNotIn('class="hi"', page)  # only the page's own language is left inline
            self.assertIn('href="/en/" hreflang="en"', hi)
            self.assertIn('href="/" hreflang="hi"', en)
            self.assertIn("Install app", en)
            self.assertNotIn("Install app", hi)
            self.assertIn("Free RRB NTPC", re.search(r"<title>(.*?)</title>", en).group(1))
            exam = (out / "en" / "exam-rrb_ntpc.html").read_text(encoding="utf-8")
            self.assertRegex(exam, r"""href=["']/en/subject-maths["']""")   # internal links stay in English
            self.assertIn('rel="canonical" href="https://example.org/en/exam-rrb_ntpc"', exam)
            paper = next((out / "en").glob("pyq-rrb-ntpc*.html")).read_text(encoding="utf-8")
            self.assertIn('class="L-hi"', paper)   # questions stay bilingual on both
            self.assertIn('class="L-en"', paper)
            sm = (out / "sitemap.xml").read_text(encoding="utf-8")
            self.assertIn("<loc>https://example.org/en/exam-rrb_ntpc</loc>", sm)
            self.assertIn('hreflang="en" href="https://example.org/en/exam-rrb_ntpc"', sm)
            self.assertTrue((out / "search-en.json").exists())
            self.assertIn('"/en/', (out / "search-en.json").read_text(encoding="utf-8")[:400])

    def test_every_internal_link_resolves(self):
        import re
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t, "--base-url", "https://example.org"],
                           check=True, capture_output=True)
            out = Path(t)

            def exists(path):
                path = path.split("#")[0].split("?")[0]
                if not path:
                    return True
                if path.endswith("/"):
                    return (out / path.lstrip("/") / "index.html").is_file()
                return (out / path.lstrip("/")).is_file() or (out / (path.lstrip("/") + ".html")).is_file()

            broken = []
            pages = list(out.glob("*.html")) + list((out / "en").glob("*.html"))
            for f in pages:
                for q, v in re.findall(r"""(?:href|src)=(["'])([^"']*)\1""", f.read_text(encoding="utf-8")):
                    if v.startswith(("http", "mailto:", "tel:", "data:", "javascript:", "#")):
                        continue
                    if not v.startswith("/") or not exists(v):
                        broken.append((f.name, v))
            self.assertEqual(broken[:5], [])
            urls = re.findall(r"<loc>https://example.org([^<]*)</loc>", (out / "sitemap.xml").read_text(encoding="utf-8"))
            self.assertGreater(len(urls), 2 * 2000)
            self.assertEqual([u for u in urls if not exists(u or "/")][:5], [])
            self.assertEqual(len([f for f in pages if f.name != "app.html"]), len(urls))  # /app is not in the sitemap
            self.assertNotIn("/app<", (out / "sitemap.xml").read_text(encoding="utf-8"))
            self.assertTrue((out / "app.html").is_file() and (out / "en" / "app.html").is_file())

    def test_app_page_is_coming_soon_until_launch_then_redirects_to_play(self):
        play = "play.google.com/store/apps/details?id=app.railpariksha"
        for live in ("", "1"):
            env = dict(os.environ, APP_LIVE=live)
            with tempfile.TemporaryDirectory() as t:
                subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t, "--base-url", "https://example.org"],
                               check=True, capture_output=True, env=env)
                out = Path(t)
                home = (out / "index.html").read_text(encoding="utf-8")
                app = (out / "app.html").read_text(encoding="utf-8")
                # Every button on every page goes to our own /app address, never straight to Google Play.
                self.assertNotIn('href="https://' + play, home)
                self.assertIn('href="/app"', home)
                if live:
                    self.assertIn(play, app)
                    self.assertIn("/app " + "https://" + play, (out / "_redirects").read_text(encoding="utf-8"))
                    self.assertIn("installUrl", home)
                else:
                    self.assertNotIn(play, app)
                    self.assertIn("t.me/RailParikshaApp", app)
                    self.assertFalse((out / "_redirects").exists())
                    self.assertNotIn("installUrl", home)

    def test_ads_only_when_configured(self):
        env = dict(os.environ, ADSENSE_CLIENT="ca-pub-1", ADSENSE_SLOT="2")
        with tempfile.TemporaryDirectory() as t:
            subprocess.run([sys.executable, str(HERE / "build_site.py"), "--out", t, "--base-url", "https://example.org"],
                           check=True, capture_output=True, env=env)
            f = next(Path(t).glob("pyq-rrb-ntpc*.html"))
            self.assertIn("adsbygoogle", f.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
