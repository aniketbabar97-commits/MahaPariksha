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

## 7. Third deepening pass: 107 -> 145 questions

**Sources re-verified and used this pass:**

- **RTA Light Motor Vehicle Handbook** (`russiadubai.com` mirror) --
  re-fetched and re-extracted (via `pdfminer.six`); confirmed live and
  unchanged (3rd edition, Jan 2012). This pass specifically mined the
  previously under-used sections: Speed Limits (Part 5, exact km/h figures
  by road class), Changing Lanes and Overtaking, the full two-lane/
  three-lane Roundabout procedures, Road Markings (regulatory/warning/
  guidance, Article 58 no-passing line), Parking Control signs and the
  Paid Parking in Dubai section (Part 6, Code A/B, fines table), and the
  Seat Belts / Alcohol-Drugs-Medicines / child-safety pages in Part 3.
- **`drivedubai.ae/en/download/`** -- retried this pass with a plain-UA
  `curl` (per instructions) and this time succeeded (HTTP 200, no
  Cloudflare challenge -- the earlier block was transient/tool-specific
  as suspected). Downloaded and opened `PTT-Motorcycle-English.ppsx` and
  `PTT-HVT-HVB-English.ppsx` (genuine PowerPoint/OOXML files, 547 and 590
  slides respectively, real theory-test Q&A content branded "Motorcycle -
  Theory Test Questions" / heavy-vehicle equivalents). Because the decks'
  own answer-key lettering is positionally shuffled and not reliably
  parseable, they were **not** used as a source of correct answers except
  where a fact is self-evidently correct on ordinary road-safety grounds
  (e.g. buying a new helmet because a second-hand one may have invisible
  impact damage) or directly resolves an existing flagged fact via a
  slide's plain question text (see below).
- **New source found and verified: RTA's own `Truck and Bus Handbook`**
  (`https://rta.ae/wpsv5/eservices/PDF_Catalog/Truck_Bus_Handbook_EN.pdf`,
  found via web search of the `rta.ae` domain itself, not a third-party
  mirror). Downloaded (4.9MB, 36 pages) and opened with PyMuPDF -- genuine,
  real extractable text: "Truck and Bus Handbook, A Guide to Safe Driving,
  3rd Edition, January 2012," with a full table of contents (Vehicle
  Checks, Coupling/Uncoupling Trailers, Dimensions and Load Limits,
  Sharing the Road, Vehicle Emergencies, etc.) -- not a marketing page or
  dead link. This directly resolved one previously-flagged question (see
  below) and is now added to the verified-sources list for future passes.
- **Rejected:** no other candidate source turned up a genuine,
  independently fetchable multi-page UAE driving-rules document this pass
  beyond the two above; nothing else was added or used.

**New content: 38 new questions, all sourced from the LMV handbook,**
across the categories flagged as thin: `speed_limits` (+6: urban single/
dual/rural/freeway km/h figures, freeway minimum speed, parking-area speed),
`highway_lane` (+6: overtake-on-the-left rule, give-way-when-overtaken rule,
where overtaking is banned, 2-second gap before pulling out, ~25-second
truck-overtake duration, no-crossing-solid-line rule), `roundabouts_
intersections` (+5: keep-right-of-island/anticlockwise rule, give-way-from-
the-left rule, two-lane turn-right/turn-left procedures, three-lane
left-lane-reserved-for-left-turns rule, main-road priority rule),
`alcohol_fatigue` (+4: the handbook's 14.33% Dubai alcohol-crash figure,
how alcohol/drugs impair risk judgement, the "arrange a sober
driver/taxi" advice, rumble strips helping drowsy drivers), `seatbelt_
child_safety` (+4: rear-facing seat/airbag danger, back-seat-until-13 rule,
booster-seat-until-145cm rule, pregnant-women-must-also-buckle-up rule),
`parking_rules` (+6: Code A/B stay limits, and four exact fine figures from
the Paid Parking Violations table -- non-payment/lost ticket AED150,
exceeding duration AED100, disabled-bay-without-permit AED500, plus the
"no parking even if sitting in the vehicle" rule), `road_signs` (+4:
No Stopping signs, loading/unloading zone signs, the Article 58 solid-line
citation, diagrammatic warning signs), `traffic_rules_row` (+2: Article 1's
general duty-of-care rule, Article 36's give-way-when-turning rule), and
`motorcycle` (+1: buy-new-not-secondhand-helmet, on general safety
grounds). All 38 were authored in English + Arabic first from the
re-extracted handbook text, then independently translated into all 12
languages with a self-QA read-through per language (structure, numerals,
and meaning spot-checked against the English/Arabic source); none needed a
`needsVerification` flag, since each is a direct, specific handbook fact
(or, for `mc015`, uncontroversial general motorcycle-safety knowledge).

**Verification flags resolved this pass (2 of the prior 12):**

- `hv012` (heavy-vehicle rest-break rule) -- previously flagged as
  "exact hour thresholds ... not confirmed." Resolved using the newly
  found RTA Truck and Bus Handbook (Part 2, "Take Breaks"): "Never drive
  for more than 10 hours in any 24 hour period." The question was
  rewritten to ask this exact figure and `needsVerification` cleared, in
  all 12 languages.
- `mc010` (motorcycle helmet law for pillion passengers) -- previously
  flagged since the statutory article wasn't directly confirmed. The
  Drive Dubai motorcycle theory-test deck's plain question text confirms
  the practical rule taught to UAE riders: "When riding with a pillion
  passenger, helmet is required for both rider and pillion passenger."
  The question's answer was already correct; `needsVerification` cleared
  and the explanation updated to cite this source honestly (a training
  deck, not the statute text itself), in all 12 languages.
- **Left flagged (10 remaining):** `sl003`, `fp005`, `fp006`, `pr003`,
  `af001`, `vd002`, `vd006`, `mc011`, `mc012`, `hv006` -- none of this
  pass's sources (LMV handbook re-read, Truck and Bus Handbook, or the
  motorcycle/heavy-vehicle decks) happened to cover these specific facts
  with a directly citable, unambiguous statement.

**Total after this pass: 145 questions** (was 107), still 12 categories,
now 10 questions flagged `needsVerification: true` (was 12). Validation:
`python3 pipeline/build_bundle.py` builds all 145 questions x 12 languages
cleanly (`Build OK.`); `python3 pipeline/validate.py` reports
`OK: 145 questions, 12 categories, 10 flagged needsVerification.` Every
touched `content/questions_<lang>.json` file was checked with
`python3 -m json.tool`.

**`pipeline/validate.py` fix:** the question-count sanity check's `60-80`
range was a leftover from the original scaffold and had been producing a
misleading `WARN` since the app passed 80 questions several passes ago. It
now warns outside `60-800` (the project's real target range from the task
brief) instead.

**Scope note (again):** the task's aim was 60-100 new questions this pass;
38 were delivered, prioritising verified accuracy and full independent
12-language translation over hitting the top of the range. The next pass
should: (a) mine the remainder of the newly-found Truck and Bus Handbook
(vehicle checks, coupling/uncoupling trailers, load limits, braking
distances, construction-zone driving) for further `heavy_vehicle` content
and possibly resolve `hv006`; (b) revisit the Drive Dubai motorcycle deck
with an OCR/positional-layout approach that can reliably recover its
answer key, to safely mine `mc011`/`mc012`-type facts; and (c) keep
looking for an Abu Dhabi/ADNOC or Sharjah driving-institute source to
diversify beyond Dubai RTA material.

## 8. Fourth deepening pass: 145 -> 159 questions

**Sources re-verified this pass (from local session cache, since fresh network
fetches of the mirrors were unreliable this pass -- see below):**

- **RTA Light Motor Vehicle Handbook** (3rd ed., re-extracted text from the
  prior pass's cached PDF) -- re-read directly; confirmed genuine again
  (same Article citations, Part numbering, fines table). This pass mined
  previously under-used sections: the "Your Responsibilities in a Crash"
  page (Part 5 -- 6-hour police notification rule, Article 12 duty-to-assist,
  moving driveable vehicles aside), the RTA Easy Licensing / registration
  renewal section (Trusted Agents requiring insurance purchase), and the
  "Driving When Tired" page (Article 10.7 citation and the "13 people died
  in one month" statistic).
- **RTA Truck and Bus Handbook** (3rd ed., re-read from cached extracted
  text) -- mined Part 3 "Vehicle Checks" (the exact pre-trip-inspection line
  about rocks/mud between dual wheels unbalancing a wheel and damaging tyre
  sidewalls/wheel bearings -- this directly resolves `hv006`, see below) and
  Part 6 "Vehicle Control" (air-brake ~1-second delay, brake fade and how to
  prevent it, cut-in on turns, trailer reversing direction) and Part 7
  (12-15 second look-ahead rule, aquaplaning, construction-zone caution).
- **Drive Dubai motorcycle/heavy-vehicle decks** (re-read from cached
  extracted slide text) -- searched again for lane-splitting and exact
  pillion-passenger-count rules to resolve `mc011`/`mc012`; found supporting
  context (pillion helmet requirement, general pillion safety practice) but
  nothing that gives an unambiguous, directly-quotable statutory statement
  for either flagged fact, so both remain honestly flagged.

**New source search this pass (rejected):** attempted to reach the Abu
Dhabi Department of Municipalities and Transport (`dmt.gov.abudhabi`) and
Sharjah's SDI (`sdi.gov.ae`) driver-licensing pages to diversify beyond
Dubai RTA material, as suggested. Both connections were refused by this
session's egress proxy at the network layer (`502`/`connect_rejected`,
organization policy) before any page content could be fetched or read, so
neither could be verified genuine or used -- nothing was added or assumed
from them. This should be retried in an environment with broader outbound
access; it is a network-policy block in this session, not a dead-link
finding about either site.

### New content: 14 new questions + 2 resolved flags, all from the two
already-verified RTA handbooks

- **`heavy_vehicle` (+6, now 20):** `hv015` air-brake ~1-second lag, `hv016`
  cause of brake fade, `hv017` shifting to a lower gear before a long
  descent to prevent it, `hv018` the 12-15 second look-ahead rule, `hv019`
  "cut-in" on turns, `hv020` a reversing trailer moving contrary to the
  steering direction -- all direct Truck and Bus Handbook Part 6/7 text,
  unflagged.
- **`vehicle_docs_insurance` (+5, now 12):** `vd008` the 6-hour crash police
  notification rule, `vd009` taking the accident form to your insurer for a
  letter to get a confiscated licence back, `vd010` moving driveable
  vehicles to the roadside after a crash (or risk a fine), `vd011`
  purchasing insurance first to renew Mulkiya via an RTA Trusted Agent,
  `vd012` the Article 12 duty to assist accident victims -- all direct LMV
  Handbook Part 5/9 text, unflagged.
- **`alcohol_fatigue` (+3, now 11):** `af009` the Article 10.7 citation
  against driving while tired, `af010` warning signs to stop and rest
  (yawning, lane drift, etc.), `af011` the handbook's own "13 people died in
  one month" Dubai statistic -- all direct LMV Handbook Part 3 text,
  unflagged.

### Verification flags resolved this pass (2 of the prior 10)

- **`hv006`** (rocks/mud between dual tyres) -- previously flagged since the
  exact mechanism couldn't be cross-checked. The Truck and Bus Handbook's
  own pre-trip-inspection checklist (Part 3, item K) states plainly: "Rocks
  or mud caught between the wheels can unbalance a wheel and damage the
  tyre side walls and wheel bearings." The question and all 12 language
  explanations were rewritten to match this exact source text and the flag
  cleared.
- **`af001`** (UAE legal blood-alcohol limit) -- previously flagged as a
  general "zero tolerance" claim without a direct quote. The LMV Handbook's
  Part 3 text states outright: "Driving under the influence of alcohol or
  drugs... there is zero tolerance for drink driving in Dubai." The
  explanation in all 12 languages was updated to cite this line directly
  and the flag cleared.
- **Left flagged (8 remaining):** `sl003`, `fp005`, `fp006`, `pr003`,
  `vd002`, `vd006`, `mc011`, `mc012` -- none of this pass's re-reads
  (radar-tolerance policy, licence-without-a-valid-one specifics,
  black-point expiry period, free-parking-hours specifics, expired-Mulkiya
  driving penalty specifics, "friendly report" procedure, motorcycle
  lane-splitting, and exact pillion-passenger limits) turned up an
  unambiguous, directly-quotable statement in the sources re-read this
  pass.

**Total after this pass: 159 questions** (was 145), still 12 categories,
now 8 questions flagged `needsVerification: true` (was 10). Validation:
`python3 pipeline/build_bundle.py` builds all 159 questions x 12 languages
cleanly (`Wrote app bundle... 159 questions x 12 languages, all
translationStatus=done`); `python3 pipeline/validate.py` reports `OK: 159
questions, 12 categories, 8 flagged needsVerification.` Every touched
`content/questions_<lang>.json` file was checked with `python3 -m
json.tool`, and a structural QA pass (4 non-empty options, non-empty
question/explanation text) was run programmatically across all 12
languages for every new/fixed id.

## 9. Strategy shift pass: 159 -> 182 questions (universal/logic content)

**Why the shift.** The previous two passes had diminishing returns re-mining
the same two or three UAE-specific handbooks for new numeric facts, and
attempts to reach additional official emirate sources (Abu Dhabi DMT,
Sharjah SDI) were blocked by this environment's network egress policy at the
proxy layer (a genuine access restriction documented in section 8, not a
dead link). Rather than keep retrying blocked domains, this pass generated
volume from a different, equally legitimate content type: questions that
don't need a UAE-specific statistic or fine amount to be correct, because
they rest on stable, universal driving-safety knowledge or on
international/Vienna-Convention-style road-sign conventions that UAE
signage follows (the same convention `app/lib/data/road_signs.dart`'s own
sign catalogue -- itself a prior design-system pass's real, shape-accurate
sign data -- already documents).

**New content: 23 new questions**, all authored in English + Arabic first,
then independently translated into all 12 languages with a structural QA
pass (4 non-empty options, non-empty question/explanation, per language)
run programmatically across every new id:

- **`road_signs` (+10, now 34):** ten sign-convention facts not already
  covered by the existing 24 sign questions, cross-checked against
  `road_signs.dart`'s real UAE sign catalogue for shape/colour accuracy: No
  Horn, Minimum Speed (mandatory blue circle vs. the red-ringed maximum), Turn
  Right Only, Traffic Signals Ahead warning triangle, Slippery Road warning
  triangle, Fuel Station informatory sign, the GIVE WAY sign's unique
  inverted-triangle shape, the general red = prohibition/danger colour
  convention, the general blue = mandatory/information colour convention,
  and the octagon shape being reserved exclusively for STOP. None needed a
  `needsVerification` flag -- these are standard, internationally-documented
  sign conventions, not UAE-specific numeric facts.
- **`seatbelt_child_safety` (+4, now 12):** correct seatbelt shoulder-strap
  positioning, the rear seat as the generally safest position for a child
  restraint, the danger of leaving a child alone in a hot parked vehicle,
  and what a booster seat actually does (raises a child so the adult belt
  sits on the shoulder/hip, not the neck/stomach) -- universal child-safety
  knowledge, unflagged.
- **`traffic_rules_row` (+2) and `roundabouts_intersections` (+2), now 16
  and 13:** a headlight-flash courtesy signal never grants right of way (you
  remain responsible for judging it's safe), how to treat a junction whose
  signals have failed (uncontrolled-intersection caution -- flagged, since
  the exact UAE procedural expectation wasn't directly confirmed this pass),
  that UAE right of way at an unsignalled junction is set by actual signs/
  markings/road hierarchy rather than a blanket "yield to the right" rule
  from some other countries' conventions (flagged, since this is a common
  cross-country source of confusion and the precise statutory wording
  wasn't confirmed), and the "zip merge" technique for a lane closure
  (unflagged, universal driving technique).
- **`highway_lane` (+1) and `speed_limits` (+1):** the physics of stopping
  distance (reaction distance plus braking distance, which grows with the
  square of speed) -- universal physics, not a country-specific number,
  unflagged.
- **`alcohol_fatigue` (+1):** severe fatigue impairs reaction time and
  judgement in ways that resemble alcohol impairment -- a well-established,
  universal road-safety fact, unflagged.
- **`parking_rules` (+1):** checking mirrors/traffic before opening a car
  door -- universal safety practice, unflagged.
- **`motorcycle` (+1):** full protective gear (not just a helmet) reduces
  whole-body injury risk -- universal motorcycle-safety knowledge, unflagged.

**Flags:** 2 of the 23 new questions (`tr016`, `ri012`) carry
`needsVerification: true`, both because the *general safety logic* is sound
and universal but the *exact UAE procedural/statutory wording* wasn't
directly confirmed this pass (malfunctioning-signal procedure; whether UAE
law states right-of-way determination in exactly these terms). No new flag
was added for a fine amount or numeric threshold -- consistent with this
pass's brief that the "safer category" framing must never be used to sneak
in an unverified specific figure. Total flags: 10 (unchanged from the 8
pre-existing ones, plus these 2 new ones -- 8 + 2 = 10).

**Total after this pass: 182 questions** (was 159), still 12 categories, 10
questions flagged `needsVerification: true` (was 8). Validation:
`python3 pipeline/build_bundle.py` builds all 182 questions x 12 languages
cleanly (`Wrote app bundle... 182 questions x 12 languages, all
translationStatus=done`); `python3 pipeline/validate.py` reports `OK: 182
questions, 12 categories, 10 flagged needsVerification.` Every touched
`content/questions_<lang>.json` file was checked with `python3 -m
json.tool`, and a programmatic structural QA pass (4 non-empty options,
non-empty question/explanation) was run across all 12 languages for every
new id.

**Scope note:** the task's aspirational target for this pass was 100-150
new questions, on the reasoning that universal/logic content doesn't
require slow source-mining. This pass delivered 23 -- well under that
target. The honest reason is time/effort budget within this session, not a
content-availability limit: unlike the handbook-mining passes, this
category genuinely has room for 100+ more good-quality questions (further
sign types, more hazard-perception scenarios, more defensive-driving
topics such as mirror checks, tyre maintenance, weather driving, blind-spot
awareness) without hitting the network-access or single-source limits that
constrained sections 6-8. The next pass should continue mining this same
"universal/logic" vein to close the gap toward the stretch target, and can
also revisit `dmt.gov.abudhabi`/`sdi.gov.ae` if run in an environment with
less restrictive egress.

**Scope note (section 8's pass):** this pass added 14 new questions plus 2 resolved flags (16
edits total) -- below the 60-100 stretch target. Reasons, stated honestly:
(a) this session's live network access to new government domains
(`dmt.gov.abudhabi`, `sdi.gov.ae`) was blocked by the egress proxy at the
policy layer, so the planned "second independent emirate source" could not
be added this pass; (b) the two already-verified handbooks' remaining
unmined sections (eco-driving tips, the theory-lesson attendance record,
detailed load-limit/coupling diagrams, bus-specific rules in Part 12) still
have real content left for a future pass, but this pass prioritised
correctness and full independent 12-language translation with a
line-by-line self-QA pass over speed. The next pass should: (a) retry
`dmt.gov.abudhabi`/`sdi.gov.ae` (and any other emirate driving-institute
domain) from an environment with less restrictive egress, or ask the user
for a pre-fetched copy; (b) mine the Truck and Bus Handbook's Parts 4
(coupling/uncoupling), 5 (load limits/dimensions) and 12 (driving a bus)
for further `heavy_vehicle` content; (c) revisit `sl003`/`fp005`/`fp006`/
`pr003` against the RTA's public traffic-fines portal (`traffic.rta.ae`)
if that domain is reachable, since these are exactly the kind of
"current/official portal" facts the two static handbooks don't state.
