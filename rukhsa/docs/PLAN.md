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
