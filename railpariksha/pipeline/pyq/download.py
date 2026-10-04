"""Download the response-sheet PDFs listed in catalog.json (resumable, polite).

Catalog source: github.com/mha93587-beep/rrb-pyq-telegram-uploader (data/*.json),
which indexes the official RRB/RPF response sheets that Adda247 hosts for free.
Files are cached under --out by URL hash; existing files are skipped.

  python3 pipeline/pyq/download.py --out /tmp/pyq-pdfs [--delay 1.0]
"""
import argparse
import hashlib
import json
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent


def name_for(url):
    return hashlib.sha1(url.encode()).hexdigest()[:16] + ".pdf"


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--delay", type=float, default=1.0)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    cat = json.loads((HERE / "catalog.json").read_text(encoding="utf-8"))
    ok = skip = fail = 0
    for i, r in enumerate(cat):
        dest = out / name_for(r["url"])
        if dest.exists() and dest.stat().st_size > 1000:
            skip += 1
            continue
        try:
            req = urllib.request.Request(r["url"], headers={"User-Agent": "Mozilla/5.0 (RailPariksha PYQ importer)"})
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = resp.read()
            if not data.startswith(b"%PDF"):
                raise ValueError("not a PDF")
            dest.write_bytes(data)
            ok += 1
        except Exception as e:
            fail += 1
            print(f"FAIL {r['url']}: {e}", flush=True)
        if (i + 1) % 50 == 0:
            print(f"{i + 1}/{len(cat)} ok={ok} skip={skip} fail={fail}", flush=True)
        time.sleep(a.delay)
    print(f"done ok={ok} skip={skip} fail={fail}", flush=True)
