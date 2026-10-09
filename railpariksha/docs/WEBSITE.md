# Website (SEO + ad revenue)

`pipeline/build_site.py` builds about 2,700 static pages: home, exams, subjects, topics, and one page per
previous-year paper and subject (`pyq-...html`) with the real questions, answers and bilingual explanations,
plus `sitemap.xml` and `robots.txt`.

## Putting it online (free, about 15 minutes)
GitHub Pages in this repo already serves another site, so use **Cloudflare Pages** (free, no limits that matter):
1. Cloudflare dashboard, Workers & Pages, Create, Pages, connect this GitHub repo, branch `aniketai/relaxed-albattani-6kjmc7`.
2. Build command: `python railpariksha/pipeline/build_site.py --out dist`   Output directory: `dist`
3. Environment variable `SITE_URL` = your final address (for example `https://railpariksha.pages.dev` now, your own domain later).
4. Python version: set `PYTHON_VERSION` = `3.12`.
5. Deploy. Every merge rebuilds the site.
6. Later: buy a domain and attach it in Pages, then change `SITE_URL`.
7. In Google Search Console add the site and submit `SITE_URL/sitemap.xml`.

## Turning on ads (only after Google approves the site)
1. Apply at adsense.google.com with your site. Approval looks at original, useful content, an about/privacy page and
   a working site; there is no fixed traffic minimum. It can take days to weeks, and pages written only to rank get
   rejected. These pages carry real questions with explanations, which is what it wants.
2. After approval create one display ad unit and copy its client id (`ca-pub-...`) and slot id.
3. In Cloudflare add `ADSENSE_CLIENT` and `ADSENSE_SLOT`, redeploy. Ads then appear twice per page. With them unset, no ad code is added.
4. `app-ads.txt` for AdMob is already generated at the site root (publisher `pub-9100209280220037`). For AdSense, add the line it gives you if it asks.

## What to expect
Indian education traffic usually pays about $1 to $5 per 1,000 page views. Search traffic to new pages takes weeks
to months to build. Treat the site as a slow second income stream and a way to send people to the app.
