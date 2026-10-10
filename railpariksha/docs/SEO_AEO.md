# SEO / AEO site — what's implemented

`pipeline/build_site.py` generates the static marketing/SEO site. As of this change it produces
89 pages (was 71): the home page, 9 exam pages, 8 new subject overview pages, 70 topic pages, and
the privacy policy — plus `sitemap.xml` and `robots.txt`.

## Structured data (JSON-LD), by page type

- **Exam pages** (`exam-*.html`): `Course` schema — name/description/provider, `about` (subject
  list) and `additionalProperty` (`PropertyValue`) entries for each subject's weightage % and the
  exam's negative marking, plus an `FAQPage` block (bilingual: syllabus/weightage question,
  negative-marking question).
- **Topic pages** (`<subject>-<topic>.html`, e.g. `maths-si_ci.html`): `Quiz` schema with up to 10
  sample questions as `Question`/`acceptedAnswer` pairs (the full question list stays in the
  visible HTML; the JSON-LD is capped to keep payload size sane on topics with 100+ questions),
  plus a small `FAQPage` ("how many practice questions exist for this topic").
- **Subject pages** (new: `subject-*.html`): `ItemList` of the subject's topics, linking both to
  the topics and to every exam that includes the subject (with that exam's weightage %).
- **Every page**: `BreadcrumbList` (Home › Subject › Topic, or Home › Exam).
- **Home page**: `Organization` + `WebSite`.

## Every factual claim is sourced from `content/taxonomy.json` / `content/bank/*.json`

- Subject weightage percentages → `taxonomy.json` `exams[].subjects[].w`.
- Negative marking (1/3 for RRB exams, 1/4 for RPF/DFCCIL) → `taxonomy.json` `exams[].neg`. This
  matches the Play Store listing text ("1/3 for RRB, 1/4 for RPF") in `docs/store/*.md`, which is
  a second independent confirmation.
- Question counts per topic/subject → counted live from `content/bank/*.json` at build time, not
  hardcoded.
- **Not claimed anywhere**: total question count per exam, exam duration, total marks, or exam
  dates — `taxonomy.json` has no such fields, so no FAQ or schema claims them. If this data is
  added to `taxonomy.json` later, the corresponding FAQ entries should be added in
  `pipeline/build_site.py` (see `faq_pairs` in the exam-page loop).

## AEO formatting

Every page now opens with a `.answer` block directly under the `<h1>` — a 2–3 sentence, bilingual,
direct-answer paragraph (e.g. exam pages state the subject weightage breakdown and negative
marking immediately, before the subject cards). This is the block most likely to be lifted
verbatim by AI Overviews / answer engines.

## Standard SEO hygiene

One `<h1>` per page (verified programmatically across all 89 generated pages), logical H2 nesting,
absolute canonical URLs, Open Graph + Twitter Card tags, and breadcrumb navigation with internal
links connecting exam ↔ subject ↔ topic pages so crawlers can reach full site depth from the home
page (home → exam/subject cards → topic pages → back up via breadcrumbs and "part of subject" /
"appears in these exams" links).

## Domain placeholder

No production domain is live yet (see `docs/LAUNCH.md`). `build_site.py` defaults to
`https://railpariksha.in` for canonical/OG/sitemap/JSON-LD URLs when `--base-url`/`SITE_URL` is
not passed (previously these were relative "/page.html", which is invalid for sitemap `<loc>` and
schema.org `url` fields). Pass the real `--base-url` once the domain is live.

## Verification performed

- `python3 pipeline/build_site.py --out <dir>` run both with and without `--base-url`.
- Parsed every `<script type="application/ld+json">` block across all generated pages with
  `json.loads` — 255 blocks, 0 parse errors.
- Spot-checked the `Course` JSON-LD for `exam-rrb_ntpc.html` against `taxonomy.json` by hand:
  weightage percentages and the negative-marking fraction matched exactly.
- Spot-checked `subject-maths.html`: topic count (15) and total question count (1164) equal the
  sum of the per-topic counts computed from `content/bank/*.json`.
- Programmatically checked all 89 pages have exactly one `<h1>`.
- Programmatically checked every internal `href="...html"` link resolves to a file that was
  actually generated (0 broken links).
- Confirmed `sitemap.xml` priorities: home=1.0, exam pages=0.9, subject pages=0.7, topic pages=0.5,
  privacy=0.3, and that `robots.txt` references the sitemap.
