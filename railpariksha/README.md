# RailPariksha (रेलपरीक्षा) — Train to succeed

Hindi/English, offline-first MCQ practice app for Indian Railways recruitment exams: RRB NTPC (UG/Graduate),
RRB Group D, RRB ALP & Technician, RRB Junior Engineer, RRB Paramedical, RPF Constable and RPF Sub-Inspector.

No courses, no sign-up, no hidden charges: exam-wise practice, best-in-class explanations, Daily 10,
spaced-repetition flashcards, mistake book, timed mocks with each exam's real negative marking (1/3 for RRB,
1/4 for RPF), a speed round, streaks, XP, train-class levels and daily motivation.

This is a sibling app to **Bharari** (`app/`, `content/`, `pipeline/`, `docs/` at the repo root) living in the
same repository — everything RailPariksha needs is self-contained under this `railpariksha/` folder, with its
own package id (`app.railpariksha`), content, CI and release pipeline. The two apps never share files.

## Repository

| Path | What |
|---|---|
| `app/` | Flutter Android app (`app.railpariksha`) |
| `content/taxonomy.json` | Subjects → topics, exams → subjects, negative marking |
| `content/bank/*.json` | Bilingual MCQs (`q/o/e` in `_hi`/`_en`, `a` = 0-based key) |
| `content/flashcards/`, `content/motivation/`, `content/notes/` | Flashcards, daily motivation, topic notes & mind maps |
| `pipeline/validate.py` | Schema/taxonomy validator |
| `pipeline/build_bundle.py` | Builds `app/assets/content/bundle.json` (the offline pack) |
| `pipeline/ca_daily.py` | Daily current affairs: news → Gemini/Grok draft → cross-check → optional Claude gate → PR |
| `pipeline/build_site.py` | SEO website + privacy policy from the question bank |
| `docs/` | Plan, launch checklist, store listing |

CI/release workflows live at the repo root under `.github/workflows/railpariksha_*.yml`, kept fully separate from
Bharari's `ci.yml` / `release.yml` / `content_pack.yml` / `current_affairs.yml`.

## Develop

```bash
python3 pipeline/validate.py          # check content
python3 pipeline/build_bundle.py      # refresh the app's offline pack
cd app && flutter pub get && flutter test && flutter run
```

## Multi-model content pipeline

`pipeline/ca_daily.py` drafts and cross-checks current-affairs MCQs using Gemini and/or Grok (cost-effective for
high daily volume), and — when `ANTHROPIC_API_KEY` is set — runs one more independent blind-solve through Claude
as a final accuracy gate before anything is kept. See the module docstring for env vars, and `docs/PLAN.md` for
the reasoning behind that division of work.

Launch steps that need your accounts are in [`docs/LAUNCH.md`](docs/LAUNCH.md). Product plan and roadmap are in
[`docs/PLAN.md`](docs/PLAN.md).
