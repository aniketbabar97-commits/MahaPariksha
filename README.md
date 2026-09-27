# Bharari (भरारी) — उंच भरारी घ्या

Marathi-first, offline-first MCQ practice app for Maharashtra and national competitive exams:
Police Bharti, Talathi, ZP, MPSC (Rajyaseva, Group B/C), Van Rakshak, Arogya, MAHA TET/CTET,
SSC, RRB, IBPS/SBI, UPSC prelims, NDA/CDS, Agniveer and the RTO learner test.

No courses, no sign-up, no hidden charges: exam-wise practice, best-in-class explanations,
Daily 10, spaced-repetition flashcards, mistake book, timed mocks with each exam's negative
marking, speed rounds, streaks, XP levels and daily motivation.

## Repository

| Path | What |
|---|---|
| `app/` | Flutter Android app (`app.bharari`) |
| `content/taxonomy.json` | Subjects → topics, exams → subjects, negative marking |
| `content/bank/*.json` | Bilingual MCQs (`q/o/e` in `_mr`/`_en`, `a` = 0-based key) |
| `content/flashcards/`, `content/motivation/` | Flashcards and daily motivation |
| `pipeline/validate.py` | Schema/taxonomy validator — CI blocks invalid content |
| `pipeline/build_bundle.py` | Builds `app/assets/content/bundle.json` (the offline pack) |
| `pipeline/ca_daily.py` | Daily current affairs: news → Claude draft → blind-solve check → PR |
| `pipeline/build_site.py` | SEO website + privacy policy from the question bank |
| `.github/workflows/` | CI, Play release, daily current affairs, content-pack publishing |
| `docs/` | Plan, launch checklist, syllabus research, content review log, store listing |

## Develop

```bash
python3 pipeline/validate.py          # check content
python3 pipeline/build_bundle.py      # refresh the app's offline pack
cd app && flutter pub get && flutter test && flutter run
```

## Content quality process

1. Authors write original questions per the explanation standard (why right, why each
   distractor is wrong, memory hook, related fact).
2. Numeric and logic items are verified by code; facts must be stable and verifiable.
3. An independent reviewer re-solves every item blind and fixes or deletes doubtful ones
   (`docs/review_log.md`).
4. In the app, one tap on "Report" hides a question for that user; reports come to the team by email.

Launch steps that need your accounts are in [`docs/LAUNCH.md`](docs/LAUNCH.md).

---

# Rukhsa — UAE Driving Test

A second, fully independent app lives under [`rukhsa/`](rukhsa/): an
offline-first MCQ practice app for the UAE RTA driving theory test, blue/gold
branded, no sign-up and no courses — the same practice-first philosophy as
Bharari, built as its own Flutter project (package `app.rukhsa`) with its own
content, pipeline and docs.

| Path | What |
|---|---|
| `rukhsa/app/` | Flutter app (`app.rukhsa`) — Material 3, RTL-aware, 12-language UI |
| `rukhsa/content/taxonomy.json` | RTA-style categories: road signs, right of way, speed limits, fines/black points, highway/lane discipline, roundabouts, parking, seatbelts/child safety, alcohol/fatigue, vehicle docs/insurance — fully translated into all 12 languages |
| `rukhsa/content/questions_en.json` | Canonical question bank (id, category, answer index, `needsVerification` flags) — 61 questions across the 10 categories |
| `rukhsa/content/questions_<lang>.json` | One file per language (ar, ur, hi, tl, ml, bn, ta, fa, fr, zh, ru) — every question, option and explanation fully and independently translated, no English fallback |
| `rukhsa/content/ui_strings.json` | Shared UI strings translated into all 12 languages |
| `rukhsa/pipeline/build_bundle.py` | Validates every language file against the canonical bank and builds `rukhsa/app/assets/content/bundle.json` (all `translationStatus: "done"`, no pending) |
| `rukhsa/docs/PLAN.md` | Content sourcing plan, verified vs needs-verification status, language rollout, self-verification notes, next steps |

```bash
cd rukhsa
python3 pipeline/build_bundle.py    # validate all languages + refresh app/assets/content/bundle.json
python3 pipeline/validate.py        # structural check of the built bundle
cd app && flutter pub get && flutter test && flutter run
```

Supported languages: English, Arabic, Urdu, Hindi, Tagalog, Malayalam,
Bengali, Tamil, Farsi, French, Chinese (Simplified), Russian. Every UI string
and every question/option/explanation is fully and independently authored in
all 12 languages (no English-fallback/"pending" content ships); each
translation pass was followed by a second, independent self-verification
read-through. Any specific fact (a fine amount, a numeric threshold) the
translator wasn't fully confident is current is flagged
`needsVerification: true` for a future check against the official RTA
handbook — see `rukhsa/docs/PLAN.md` for details. Store listing and
search-ranking (ASO) work is intentionally out of scope for now.
