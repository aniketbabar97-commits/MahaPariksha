# Rukhsa — UAE Driving Test: Content & Product Plan

Rukhsa is an offline-first MCQ practice app for the UAE RTA (Roads and
Transport Authority) driving theory test, styled after the existing Bharari
app in this repo but as a fully independent product (own Flutter project,
package `app.rukhsa`, no shared code with Bharari).

## 1. Content sourcing plan

This first pass (59 questions across 10 categories) was written from general
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

- 59 total questions, 14 flagged `needsVerification: true`.
- Run `python3 pipeline/validate.py` after building the bundle to see the
  current counts, or filter `content/bank/*.json` for `"needsVerification": true`.
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
| Chinese, Simplified (zh) | Translated | Authored (real translation) |
| Russian (ru) | Translated | Authored (real translation) |
| Urdu, Hindi, Tagalog, Malayalam, Bengali, Tamil, Farsi, French | Translated | English fallback, `translationStatus: "pending"` per question/field (unless overridden by a `content/questions_<lang>.json` file) |

The bundle schema (`build_bundle.py`) always carries all 12 languages per
question so the app never has to special-case a missing key, but it is
explicit in the data about which text is a real, reviewed translation
(`"done"`) versus an English placeholder (`"pending"`). The next content pass
should prioritise getting Urdu and Hindi to `"done"`, since they cover the
largest share of the UAE's resident/expat driving-test population, before the
remaining languages.

## 4. Next steps

- Get real (reviewed) translations for the remaining "pending" languages,
  starting with Urdu and Hindi.
- Verify every `needsVerification: true` question against the official RTA
  handbook and current fine/black-point schedule, then flip the flag.
- Grow the bank from 59 to 300+ questions once content is verified, to
  support realistic mock-exam-length sessions (25-40 questions) without
  repeats.
- Add a "mock exam" mode (fixed-length, timed, pass/fail against the
  60-70% threshold) on top of the existing per-category practice mode.
- **Store listings and search ranking (ASO):** out of scope for this pass.
  When it's time, this needs its own effort — App Store/Play Store
  copy in the app's priority languages, keyword research for terms like
  "RTA test", "UAE driving theory", "Mulkiya test practice", screenshots, and
  a review-prompt strategy. Placeholder only; do not write ASO copy yet.
