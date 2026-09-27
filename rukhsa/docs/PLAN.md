# Rukhsa — UAE Driving Test: Content & Product Plan

Rukhsa is an offline-first MCQ practice app for the UAE RTA (Roads and
Transport Authority) driving theory test, styled after the existing Bharari
app in this repo but as a fully independent product (own Flutter project,
package `app.rukhsa`, no shared code with Bharari).

## 1. Content sourcing plan

This first pass (61 questions across 10 categories) was written from general
public knowledge of how the Dubai RTA / Abu Dhabi (Al Ain, ADNOC) Light Motor
Vehicle theory test is structured and what it commonly covers. It is a
**study organiser and starter question bank, not a transcription of any
official exam**. Before this content is presented as authoritative, it should
be checked against:

1. **The official RTA Light Motor Vehicle Driver's Handbook** (Dubai RTA) —
   the canonical source for road signs, right-of-way rules, and procedures.
2. **Each emirate's own traffic authority material** where rules differ
   (Abu Dhabi/ADNOC driving institutes, Sharjah, etc.) — fine amounts, black
   point thresholds, and some local rules can vary by emirate and change
   over time.
3. **Public practice-question archives and driving-school material** — useful
   for cross-checking phrasing and common exam patterns, not as a copy source.
4. **An AI-assisted structuring pipeline** (the `pipeline/` scripts in this
   folder) to keep authoring, translation-fallback generation, and bundle
   validation consistent and repeatable as more questions are added.

## 2. Verified vs needs-verification

Every question has a `needsVerification` flag. It is `true` wherever the
question turns on a specific number, threshold, or legal detail (fine
amounts, black-point counts, exact age/height cutoffs for child seats, speed
buffer policy, licence renewal cadence, etc.) that should be double-checked
against the current official handbook/regulations before being treated as
fact. As of this pass:

- 61 total questions, 17 flagged `needsVerification: true`.
- Run `python3 pipeline/build_bundle.py` to rebuild and see the current
  per-language counts, or grep `content/questions_en.json` for
  `"needsVerification": true`.
- Nothing in the "verified" (unflagged) set states a specific fine amount or
  point count — those are exactly the kind of fact that is flagged instead.

## 3. Language rollout status

Twelve languages are wired end-to-end in both the UI (ARB files under
`app/lib/l10n/`) and the question schema: English, Arabic, Urdu, Hindi,
Tagalog, Malayalam, Bengali, Tamil, Farsi, French, Chinese (Simplified),
Russian. This set covers every language the official Dubai RTA computer
theory test is offered in (Arabic, English, Urdu, Hindi, Malayalam,
Tagalog/Filipino, Farsi, French, Chinese, Russian) plus Bengali and Tamil for
major learner-demand coverage.

| Language | UI strings | Question content |
|---|---|---|
| English (en) | Translated | Authored (source language) |
| Arabic (ar) | Translated | Authored (real translation) |
| Urdu (ur) | Translated | Authored (real translation) |
| Hindi (hi) | Translated | Authored (real translation) |
| Tagalog (tl) | Translated | Authored (real translation) |
| Malayalam (ml) | Translated | Authored (real translation) |
| Bengali (bn) | Translated | Authored (real translation) |
| Tamil (ta) | Translated | Authored (real translation) |
| Farsi (fa) | Translated | Authored (real translation) |
| French (fr) | Translated | Authored (real translation) |
| Chinese, Simplified (zh) | Translated | Authored (real translation) |
| Russian (ru) | Translated | Authored (real translation) |

**Update (this pass): the `"pending"` English-fallback approach described in
the paragraph below has been retired at the user's explicit direction.**
`rukhsa/content/bank/` (the old per-category source with only en/ar/zh/ru
authored inline and the other 8 languages falling back to English) has been
removed. The single source of truth is now flat, per-language files —
`rukhsa/content/questions_<lang>.json` for all 12 languages, sharing ids with
the canonical `questions_en.json` (which alone carries `category`, `sub`,
`answer`, `needsVerification`) — rebuilt by `pipeline/build_bundle.py` into
`app/assets/content/bundle.json` in the same shape the Flutter app already
expects (`Localized` map of `{text, translationStatus}` per language), except
every entry is now `translationStatus: "done"`. The build script fails loudly
if any language file is missing or incomplete for any question id — there is
no silent English fallback path left in the pipeline.

### Self-verification pass (this pass)

Every one of the 12 language files (61 questions x 4 options + explanation
each) was authored independently, then re-read in a second, separate pass
against the English/Arabic source meaning — checking for accuracy, natural
phrasing, and (for RTL languages) correct directionality of quoted numbers/
Latin terms (e.g. "Mulkiya", "Salik", km/h). Spot-checks covered every
language at least once (Tamil, Bengali, Farsi, Chinese, Russian, Urdu,
Tagalog, Malayalam, Hindi, French) and an automated structural pass (script,
not just eyeballing) confirmed for all 12 language files: every question has
exactly 4 non-empty options, a non-empty question and explanation string, and
the shared `answer` index is in range 0-3. No `translationStatus: "pending"`
or copied-English placeholder exists anywhere in the shipped content.

Any specific number or legal fact a translator was not fully confident is
still current — a fine amount, a black-point count, an age/height cutoff, a
speed-limit figure — is flagged `needsVerification: true` on the English
(canonical) record, which every language's build picks up. This flag is
strictly about fact-checking against the official RTA handbook and is never
used as an excuse to leave a translation undone; every flagged question still
has a complete, real translation in all 12 languages. 17 of the 61 questions
currently carry this flag (see `content/questions_en.json`, search
`needsVerification`); nothing "verified" states a specific number.

## 4. Next steps

- All 12 languages now have real, self-verified translations for every UI
  string and question/option/explanation — no further translation-fallback
  work is outstanding.
- Verify every `needsVerification: true` question against the official RTA
  handbook and current fine/black-point schedule, then flip the flag.
- Grow the bank from 61 to 300+ questions once content is verified, to
  support realistic mock-exam-length sessions (25-40 questions) without
  repeats.
- Add a "mock exam" mode (fixed-length, timed, pass/fail against the
  60-70% threshold) on top of the existing per-category practice mode.
- **Store listings and search ranking (ASO):** out of scope for this pass.
  When it's time, this needs its own effort — App Store/Play Store
  copy in the app's priority languages, keyword research for terms like
  "RTA test", "UAE driving theory", "Mulkiya test practice", screenshots, and
  a review-prompt strategy. Placeholder only; do not write ASO copy yet.

## 5. UI/product polish pass (this branch)

Added on top of the existing app skeleton, all under `app/lib/`. (At the time
this section was written, `content/bank/`, `content/taxonomy.json` and the
l10n `.arb` files were being worked on separately; `content/bank/` has since
been retired in favour of the flat, fully-translated `questions_<lang>.json`
files described in section 3 above.)

- **Design system** (`core/theme.dart`, `core/design_system.dart`): brand
  color tokens (blue/gold from the logo) with a real light+dark `ColorScheme`,
  a spacing/radius/type scale, and a reusable widget kit — `AppCard`,
  `AppBadge`, `CategoryTile`, `ProgressRing`, `StatCard`, `AppEmptyState`.
- **App icon / brand mark** (`core/app_icon.dart` + `assets/icon/app_icon.svg`):
  the blue-field/gold-steering-wheel/car/road logo drawn as a `CustomPainter`
  (`RukhsaLogoMark`) plus a hand-authored SVG twin of the same design, since
  no image-generation tool was available. The SVG is a source asset for a
  future `flutter_launcher_icons` pass to produce real Android/iOS launcher
  icons — it is not yet wired into a launcher-icon build.
- **Road Sign Library** (`data/road_signs.dart`, `widgets/road_sign_painter.dart`,
  `screens/road_signs_screen.dart`): 20 real UAE sign types across
  priority/mandatory/prohibitory/warning/informatory categories, drawn as
  shape- and color-accurate vectors (red triangles, blue circles, red-ringed
  white prohibitory circles, blue/green rectangles, the STOP octagon and
  GIVE WAY inverted triangle), tappable for name + meaning.
- **Flashcards** (`logic/flashcard_engine.dart`, `screens/flashcards_screen.dart`):
  cards generated from the existing question bank (front = question, back =
  answer + explanation), tap-to-flip / swipe-to-grade UI, and a simplified
  SM-2 scheduler persisted in `SharedPreferences`.
- **Mind Map** (`data/topic_relations.dart`, `screens/mind_map_screen.dart`):
  a radial diagram of how syllabus categories relate (e.g. Fines & Black
  Points at the centre, connected to every category it penalizes), tap a
  node to see its links and jump into practising that topic.
- **Timed mock exam** (`logic/mock_exam.dart`, `screens/mock_exam_screen.dart`,
  `screens/mock_exam_results_screen.dart`): 35 questions / 30-minute
  countdown / 23-out-of-35 (65%) pass mark, weighted category sampling,
  auto-submit on timeout, and a weakest-category-first results breakdown.
- **Emirate + vehicle-type filters** (`data/models.dart`, `core/app_scope.dart`,
  home screen filter bar): `Question.emirate` and `Question.vehicleType`
  optional fields, defaulting to `"all"`/`"all"` (existing content is
  untagged and matches every filter), plus a Dubai/Abu Dhabi/Sharjah and
  Car/Motorcycle/Heavy Vehicle/Bus selector that narrows practice, mock
  exams and flashcards. No content is currently tagged beyond the default,
  so today the filters are structurally wired but functionally inert until a
  content pass adds real per-emirate/vehicle questions.

### Known gaps / not yet 10/10

Being honest about what's still weak after a self-review pass:

- **New-screen strings are English-only.** Road Signs, Flashcards, Mind Map
  and Mock Exam UI chrome ("Didn't know", "Practise this topic", etc.) is
  hard-coded English rather than routed through `AppLocalizations`/ARB files,
  because this pass was told to avoid touching `l10n/*.arb` (owned by the
  content/translation agent). Sign *meanings* have an English/Arabic pair
  built in, but not the other 10 UI languages. This is the single biggest
  remaining gap for a non-English/Arabic user and should be the next task
  once the l10n files are free to edit.
- **App icon is not yet a real launcher icon.** `RukhsaLogoMark` (a
  `CustomPainter`) and `assets/icon/app_icon.svg` both encode the design, but
  neither is wired through `flutter_launcher_icons` (or manually exported
  PNGs) into `android/`/`ios/` launcher assets — that step needs a real
  Flutter toolchain, which wasn't available in this environment.
  Rasterizing the SVG (or running the painter through an offscreen canvas)
  and running the launcher-icon generator is a follow-up.
- **Road sign glyphs are simplified, not photorealistic.** Pictograms (e.g.
  the roundabout-mandatory arrow, cyclist icon) are minimal vector
  approximations, not the exact RTA artwork; shapes and category colors are
  accurate, but a learner comparing pixel-for-pixel against the official
  handbook will see stylistic differences.
- **Mock exam category weights are a heuristic**, not a published RTA
  breakdown (none is publicly documented) — flagged in
  `logic/mock_exam.dart`'s doc comment; treat as a study heuristic to revisit
  if better source data turns up.
- **Emirate/vehicle-type filters have no real content behind them yet.**
  The schema and UI are forward-compatible (every question defaults to
  `"all"`), but until the content bank tags some questions with a specific
  emirate or vehicle type, selecting "Abu Dhabi" or "Motorcycle" changes
  nothing visible. This is intentional per this pass's scope (content/bank/
  was off-limits) but should not be presented to users as a fully live
  feature without a follow-up content pass.
- **No automated test coverage** was added for the new logic
  (`FlashcardScheduler`, `buildMockExam`, `Question.matchesFilters`) — only
  manual code review, since no Flutter/Dart SDK was available in this
  environment to run `flutter test` or even `dart analyze`. This should be
  the first thing verified once a real toolchain is available.
- **Mind map layout is a fixed radial diagram**, not a force-directed or
  pannable graph — fine for 10 categories, but would need real graph layout
  if the category count grows substantially.
- **Dark mode was added at the theme level** (`buildRukhsaTheme(Brightness)`)
  and spot-checked on the screens this pass touched, but every screen was
  not exhaustively re-verified pixel-by-pixel in dark mode.

## 4. Source-verification pass (this pass): 61 -> 85 questions

This pass fetched and read three candidate sources itself (never trusting a
URL without opening and checking its actual content first):

1. **RTA Light Motor Vehicle Handbook, 3rd Edition (Jan 2012), 78 pages** --
   fetched from the `russiadubai.com` mirror named in the task brief (the
   `licensing.rta.ae/handbook/lmv/lmv_en.pdf` URL does not resolve). Verified
   genuine by extracting all 78 pages of text with PyMuPDF and reading the
   content: real handbook text, table of contents, Article citations to UAE
   Federal Traffic Law No. 21 of 1995, and a full "Traffic Violations, Fines
   & Black Points" table (Part 8) with real AED amounts and black-point
   counts. **Used, and it is the strongest source in this pack.**
2. **Drive Dubai motorcycle theory-test slide deck** (`PTT-Motorcycle-English.ppsx`,
   ~9.3 MB) -- found on drivedubai.ae's own download page (a real, currently
   operating driving school), downloaded, and its slide XML parsed directly
   (python-pptx choked on the file's declared content type, so the OOXML
   `ppt/slides/slideN.xml` parts were read with `zipfile`/regex instead).
   Confirmed genuine: ~180 real motorcycle theory MCQs (brakes, mirrors,
   helmets, chain maintenance, cornering, fatigue). **Used** for authoring
   new `motorcycle` category questions, but only for questions whose correct
   answer is standard, uncontroversial road/motorcycle-safety knowledge --
   the slide deck's own "Correct" marker shape could not be matched to the
   right option with full confidence from the raw XML, so it was not relied
   on to pick answers.
3. **Drive Dubai Heavy Vehicle Truck/Bus deck** (`PTT-HVT-HVB-English.ppsx`)
   -- the task brief could not locate this deck's URL up front, but it was
   found this pass directly on drivedubai.ae's download page (not a
   marketing PDF -- confirmed 589 real slides of theory MCQs covering
   fatigue management, load security, dual-tyre checks, etc). **Used** for
   the new `heavy_vehicle` category, cross-referenced against the LMV
   handbook's fines table wherever the two overlap (lane discipline,
   overloading, falling loads, dangerous overtaking by trucks).

### Verification-flag changes on the original 61

Of the 17 originally flagged `needsVerification: true` questions, cross-checked
against the LMV handbook's fines/black-points table and rule text:

- **Corrected (fact was more specific/different than originally stated,
  updated in English + Arabic and re-translated into all 12 languages):**
  - `fp002` (24-point consequence) -> now states the handbook's actual
    escalation: 3 months' confiscation first time, 6 months second time,
    12 months + mandatory course third time.
  - `fp003` (red light) -> now states the handbook's actual figure: AED 800
    fine + 8 black points.
  - `sc001` (seatbelt requirement) -> the handbook's Article 33 citation
    legally requires only the driver and front-seat passenger, not "all
    passengers" as originally (softly) worded; corrected, with a note that
    RTA still recommends everyone buckle up.
- **Cleared (confirmed accurate/consistent with the handbook, no wording
  change needed):** `tr004`, `sl001`, `sl002`, `sl004`, `sc002`, `sc003`,
  `af004` (7 questions).
- **Left flagged (genuinely not confirmable from the sources used this
  pass):** `sl003` (radar tolerance), `fp005` (no-licence penalty specifics),
  `fp006` (black-point expiry period), `pr003` (free parking hours),
  `af001` (exact legal BAC limit), `vd002` (expired-Mulkiya specifics),
  `vd006` ("friendly report" minor-accident procedure). None of these are
  covered in the LMV handbook's extracted text.

### New content: `motorcycle` and `heavy_vehicle` categories (+24 questions)

Two new categories were added to `taxonomy.json` (translated into all 12
languages) since the original 10 categories had no motorcycle- or
heavy-vehicle-specific content: `motorcycle` (12 new questions: fatigue,
brake checks, mirrors, helmet condition, throttle/chain maintenance,
cornering position, plus UAE-specific helmet/lane-splitting/pillion rules)
and `heavy_vehicle` (12 new questions: fatigue/rest management, food choice,
dual-tyre debris, and five questions with real AED fine + black-point
figures taken directly from the LMV handbook's violations table: lane
discipline, overloading/protruding load, falling/leaking load, dangerous
overtaking by trucks, uncovered truck loads).

Of these 24, 5 remain flagged `needsVerification: true` because the exact
UAE statutory wording was not directly confirmed in the sources used this
pass (helmet law for pillion passengers, lane-splitting legality, pillion
passenger limits, dual-tyre debris mechanism, and mandatory heavy-vehicle
rest-break hour thresholds) -- each explanation says so explicitly and
names what should be checked.

All 24 new questions were authored in English and Arabic first, then
independently translated into all 12 languages (no placeholders / no
English-fallback), following the same standard as the original 61.

**Total after this pass: 85 questions** (was 61), spanning 12 categories
(was 10), with 12 questions still flagged `needsVerification: true` (was 17)
-- `python3 pipeline/validate.py` confirms `OK: 85 questions, 12 categories,
12 flagged needsVerification.` and `python3 pipeline/build_bundle.py` builds
cleanly for all 12 languages.

**Scope note:** the task's aspirational target was 150-200 new questions
(600-800 total across several passes). This pass delivered 24 new,
genuinely-sourced, 12-language questions plus a full fact-check/correction
pass on the existing 61, prioritising verification quality and real
independent translation over volume within the time available. Reaching the
600-800 target will take further passes of the same kind (more categories,
more per-category depth, and ideally acquiring the official RTA truck/bus
and motorcycle handbooks directly rather than a driving school's slide
deck, if they become available).

## 6. Deepening pass (this pass): 85 -> 107 questions

**Re-verification of prior sources, as instructed.** Both previously-cited
sources were re-checked, not assumed still good:

- **RTA Light Motor Vehicle Handbook** (`russiadubai.com` mirror) --
  re-fetched this pass, and its text re-extracted (with `pdfminer.six`,
  since PyMuPDF was not available in this environment) and read directly.
  Confirmed genuine again: real 3rd-edition (Jan 2012) handbook text,
  table of contents, Article citations to UAE Federal Traffic Law No. 21 of
  1995, the full road-signs gallery (Part 5) and the "Traffic Violations,
  Fines & Black Points" table (Part 8). **Used extensively this pass** --
  it turned out to contain far more usable, source-backed detail (individual
  sign types, roundabout/right-of-way procedure text, Salik toll figures,
  the 24-point licence-confiscation escalation) than the previous pass had
  drawn on.
- **Drive Dubai motorcycle/heavy-vehicle decks** (`drivedubai.ae/en/download/`)
  -- could **not** be re-verified this pass: the download page now returns
  an HTTP 403 from Cloudflare's bot-challenge (`cf-mitigated: challenge`)
  to this session's fetches, so its current live/genuine status could not be
  re-confirmed today. It was not treated as fake -- no content was
  authored from it this pass -- but its "verified" status in section 4
  above should be re-checked with a real browser next time before citing it
  again.

**New sources searched for and explicitly rejected:** no additional
downloadable UAE driving-school handbook or slide deck was found this pass
that could be fetched and read in full to confirm it was a genuine
multi-page rules document (rather than a marketing page or a dead/blocked
link) within the session's tool access. Nothing new was added to the
"verified sources" list as a result -- only the LMV handbook re-read above
was used for new content this pass.

### New content: 22 new questions, all sourced from the LMV handbook

All 22 are grounded directly in specific handbook text (Part 5 "Rules and
Responsibilities" for signs and right-of-way, Part 8 for fines/black points,
and the Salik section), authored in English + Arabic first and then
independently translated into all 12 languages, with a second self-read QA
pass per language checking structure (4 non-empty options, non-empty
question/explanation) and spot-reading meaning against the English source:

- **`road_signs` (+10 -- now the largest category at 20):** STOP octagon,
  No Entry, No U-turn, No Overtaking (prohibitory signs); the standard
  triangular advance-warning shape/colour convention and chevron hazard
  markers (warning signs); the freeway-control-sign category; the camel/
  animal warning sign; the roundabout-direction control sign; the blue "P"
  parking-control sign. All are common-knowledge sign shapes/colours or
  directly described in the handbook's Part 5 sign gallery, so none needed
  a `needsVerification` flag.
- **`traffic_rules_row` (+4):** give-way-to-the-left at roundabouts,
  giving way to sirens/flashing-light emergency vehicles even at a green
  light, not passing a stopped school bus with its stop-arm/flashers
  active, and giving way to pedestrians already on a marked crossing --
  all direct handbook rules, unflagged.
- **`fines_penalty` (+3):** the 24-black-point licence-confiscation
  escalation (3/6/12 months across repeat occurrences within a year), the
  AED 600 fine for illegal bus/taxi-lane use, and the escalating Salik
  no-tag fine (AED 100/200/400) -- all direct figures from the handbook's
  Part 8 table and Salik violations table, unflagged since fully sourced.
- **`vehicle_docs_insurance` (+1):** the Salik toll amount (AED 4.00 per
  crossing) and daily cap (AED 24.00), from the handbook's Salik section.
- **`motorcycle` (+2):** the "leave at least one metre" overtaking-clearance
  rule and motorcyclists'/cyclists' right to the full lane width, both
  quoted directly from the handbook.
- **`heavy_vehicle` (+2):** the hard-shoulder no-overtaking rule and the
  21-black-point penalty for a falling/leaking load, both from the
  handbook.

None of the 12 pre-existing `needsVerification: true` questions were
resolved this pass -- the handbook re-read did not happen to cover the
specific facts they turn on (radar tolerance, black-point expiry period,
free-parking hours, exact legal BAC limit, expired-Mulkiya specifics,
"friendly report" procedure, or the motorcycle/heavy-vehicle specifics
flagged from the unreachable Drive Dubai decks). They remain flagged,
honestly, rather than guessed at.

**Total after this pass: 107 questions** (was 85), still 12 categories,
still 12 questions flagged `needsVerification: true` (unchanged, since this
pass's new content was fully source-backed and none of the flagged ones
happened to be covered by the sources re-read this pass). Validation:
`python3 pipeline/build_bundle.py` builds all 107 questions x 12 languages
cleanly; `python3 pipeline/validate.py` reports
`OK: 107 questions, 12 categories, 12 flagged needsVerification.` (with an
expected `WARN` that 107 is still below the 600-800 target range -- not a
failure). Every touched `content/questions_<lang>.json` file was also
checked with `python3 -m json.tool`.

**Scope note (again):** this pass added 22 new questions -- fewer than the
20-100 stretch goal's upper end, but each one individually traced to
specific, re-verified handbook text and independently translated/QA'd in
all 12 languages, rather than rushed. Road signs, traffic rules, and fines
were prioritised as instructed since they were thinnest relative to real
exam weighting. The next pass should: (a) re-verify `drivedubai.ae` with a
real browser (or find an alternative mirror of its decks) since it is now
Cloudflare-gated for automated fetches; (b) mine the remaining unused
sections of the LMV handbook already downloaded this pass (freeways/
interchanges, parking in Dubai, crash responsibilities, eco-driving) for
further `highway_lane`, `parking_rules`, and `roundabouts_intersections`
content; and (c) keep hunting for a second independent, verifiable UAE
source (Abu Dhabi/ADNOC or Sharjah driving-institute material) to
cross-check facts against and diversify beyond the Dubai RTA handbook.
