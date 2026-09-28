# RailPariksha — product plan

Same playbook as Bharari (this repo's sibling app), retargeted at Indian Railways recruitment exams: no
courses, no sign-up, no hidden charges — exam-wise practice, best-in-class explanations, Daily 10, spaced-repetition
flashcards, a mistake book, timed mocks with each exam's real negative marking, a speed round, streaks/XP and daily
motivation. RailPariksha and Bharari are independent apps living in one repo (`railpariksha/` vs `app/`, `content/`,
`pipeline/`, `docs/` at the repo root) — different package id, different content, different CI, never mixed.

## Target exams

| Exam | Body | Subjects | Negative marking |
|---|---|---|---|
| RRB NTPC (UG/Graduate) | RRB | Maths, Reasoning, GK, Current Affairs, Railway GK, Computer | 1/3 |
| RRB Group D | RRB | Maths, Reasoning, Science, GK, Current Affairs, Railway GK | 1/3 |
| RRB ALP & Technician | RRB | Maths, Reasoning, Science, Current Affairs, Railway GK | 1/3 |
| RRB Junior Engineer (JE) | RRB | Maths, Reasoning, Science, GK, Current Affairs, Computer | 1/3 |
| RRB Paramedical | RRB | Maths, Reasoning, Science, GK, Current Affairs | 1/3 |
| RPF Constable | RPF | Maths, Reasoning, GK, Current Affairs, Railway GK | 1/4 |
| RPF Sub-Inspector (SI) | RPF | Maths, Reasoning, GK, Current Affairs, Railway GK | 1/4 |

Exam list, subject sets and negative-marking values live in `content/taxonomy.json`; adding a new exam (say RRB
Ticket Collector once its own CBT syllabus is confirmed, or CBT-2 stage variants) means adding one entry there.

## Subjects & why each exists

- **Maths** and **General Intelligence & Reasoning** — the two subjects common to every RRB/RPF CBT.
- **General Science** — RRB Group D/ALP/JE/Paramedical staple (physics/chemistry/biology basics, human body).
- **General Awareness (GK)** — static GK: polity, history, geography, economy, awards, sports.
- **Current Affairs** — separately from GK because it needs a live pipeline (see below), not a fixed bank.
- **Railway General Knowledge** — RailPariksha's differentiator versus generic GK apps: zones, gauges, notable
  trains, safety systems like Kavach, RRB/RPF's own structure. Real aspirants are tested on this and it is
  under-served by other apps.
- **Computer & Financial Awareness** — RRB NTPC/JE specific.
- **English** — language paper common across exams.

## Content quality process (same standard as Bharari)

1. Authors write original questions per the explanation standard (why right, why each distractor is wrong,
   memory hook, related fact where useful).
2. Numeric/logic items are checked by hand against the stated formula; static facts (history dates, RRB/RPF
   structure, gauge measurements) are cross-checked against more than one reference before being marked correct —
   railway facts in particular (zone counts, project names) are treated as needing citation-level care, since they
   change with government reorganisation.
3. `pipeline/validate.py` blocks anything with a bad subject/topic reference, a malformed option set, or missing
   Devanagari where Hindi text is expected.
4. In the app, one tap on "Report" hides a question for that user; reports reach the team by email.

## Why Grok + Gemini + Claude, not just one model

The daily current-affairs pipeline (`pipeline/ca_daily.py`) is built to use Grok and Gemini for the actual
generation work — they're the cost-effective choice for a high-volume, repetitive drafting task run every day —
while treating a human-reviewed PR merge as the real gate, same as Bharari. To keep the *result* at a "best model"
accuracy bar without paying for Claude on every draft:

1. One of Gemini/Grok drafts MCQs strictly from the day's news items (never from memory).
2. The other independently blind-solves each draft using only the same source text, rejecting any item where its
   answer disagrees with the draft or where it isn't confident.
3. If `ANTHROPIC_API_KEY` is configured, Claude runs one more blind-solve as the final quality gate — this is the
   expensive, highest-accuracy step, but it only runs on items that already survived step 2, so the number of Claude
   calls stays small relative to the raw draft volume.

This mirrors a "many cheap workers, one expensive reviewer" structure rather than routing everything through the
priciest model. See the module docstring in `pipeline/ca_daily.py` for the exact env vars and models.

## Roadmap

- [x] Taxonomy, starter question bank (~90+ questions across all 8 subjects), flashcards, motivation, two
      Railway GK notes/mind-maps.
- [x] Flutter app re-skinned from Bharari's proven architecture: navy/gold "Indian Railways" theme, train-class
      level progression (General → Sleeper → AC 3-Tier → AC 2-Tier → Rajdhani), Hindi/English throughout.
- [x] CI (`railpariksha_ci.yml`), release (`railpariksha_release.yml`), content-pack build
      (`railpariksha_content_pack.yml`), daily current-affairs draft (`railpariksha_current_affairs.yml`).
- [ ] Grow the question bank per subject (target 40-60 per subject before a public launch) — the schema and
      pipeline already scale to this; it's an authoring/review effort, not an engineering one.
- [ ] Notes/mind-maps for the remaining heavily-used topics (currently only 2 Railway GK topics have them; every
      other topic falls back to the "coming soon" empty state, which is honest but not yet complete).
- [ ] Wire a real hosting target for `content.json` (see `docs/LAUNCH.md` §4) so the app can update its question
      pack without a Play Store release.
- [ ] Store listing, screenshots and the account/signing steps in `docs/LAUNCH.md`.
