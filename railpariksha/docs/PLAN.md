# RailPariksha — product plan

Same playbook as Bharari (this repo's sibling app), retargeted at Indian Railways recruitment exams: no
courses, no sign-up, no hidden charges — exam-wise practice, best-in-class explanations, Daily 10, spaced-repetition
flashcards, a mistake book, timed mocks with each exam's real negative marking, a speed round, streaks/XP and daily
motivation. RailPariksha and Bharari are independent apps living in one repo (`railpariksha/` vs `app/`, `content/`,
`pipeline/`, `docs/` at the repo root) — different package id, different content, different CI, never mixed.

## Target exams

Mock tests are weighted to match each exam's real question-count split, not an even share across subjects —
`QuizBuilder.mock()` reads each subject's weight from `taxonomy.json` and allocates proportionally (with a
capped, weight-preserving fallback for thin subjects like current affairs, so a shortfall in one subject doesn't
just get dumped randomly onto whichever subject has leftover). Weights below are the real CBT1/common-stage
question counts (out of the exam's real total, shown in parentheses) reported consistently across RRB/RPF
exam-prep sources (Testbook, Adda247, Careerpower, PW, Oliveboard) as of the exams' most recent CENs:

| Exam | Body | Maths | Reasoning | Science | GK | Current Affairs | Railway GK | Computer | Real total | Negative marking |
|---|---|---|---|---|---|---|---|---|---|---|
| RRB NTPC (UG/Graduate) | RRB | 30 | 30 | — | 15 | 10 | 10 | 5 | 100 | 1/3 |
| RRB Group D | RRB | 25 | 30 | 25 | 8 | 6 | 6 | — | 100 | 1/3 |
| RRB ALP | RRB | 20 | 25 | 20 | 4 | 3 | 3 | — | 75 | 1/3 |
| RRB Technician | RRB | 20 | 25 | 20 | 4 | 3 | 3 | — | 75 | 1/3 |
| RRB Junior Engineer (JE) | RRB | 30 | 25 | 30 | 6 | 5 | — | 4 | 100 | 1/3 |
| RRB Paramedical | RRB | 8 | 8 | 8 | 3 | 3 | — | — | 30¹ | 1/3 |
| RPF Constable | RPF | 35 | 35 | — | 20 | 15 | 15 | — | 120 | 1/4 |
| RPF Sub-Inspector (SI) | RPF | 35 | 35 | — | 20 | 15 | 15 | — | 120 | 1/4 |
| DFCCIL Executive/Jr. Executive | DFCCIL (PSU) | 30 | 30 | 15² | 15 | — | 10² | — | 100 | 1/4 |

¹ RRB Paramedical's real CBT is 100 questions, but 70 of those are a category-specific professional paper (Staff
Nurse, Pharmacist, Lab Technician, etc. each have their own) that this app doesn't cover — see "What's covered vs
intentionally out of scope" below. The 30 shown is only the common general-knowledge portion, split evenly across
its subjects since the exact official sub-split isn't published; treat this one row as an estimate, not a sourced
figure like the others.

² DFCCIL's CBT1 (the common stage every applicant sits, before any post-specific technical CBT2) reports a
"General Awareness" section of 15 questions and a "Knowledge about Railways/DFCCIL" section of 10
questions in its own published pattern — mapped here onto this app's `gk` and `railway_gk` subjects
respectively, the same general/current-affairs and railway-specific split used for the RRB/RPF rows.
See `docs/RAILWAY_EXAMS_RESEARCH.md` for the sourced breakdown and for every other railway exam
researched (RRB SSE, Ministerial & Isolated Categories, RRC, other railway PSUs, metro rail) and why each
either is or isn't in taxonomy.json.

RRB's official syllabus doesn't sub-divide "General Awareness" into GK/Current Affairs/Railway GK/Computer the
way this app does for practice purposes — that four-way split (and its relative proportions within each exam's
GA weight) is this app's own pedagogical breakdown, not an officially published sub-split.

ALP and Technician are listed as separate exams (real RRB CENs run them as separate recruitment processes) even
though their CBT1 subject pattern is identical — this matches how RRB actually structures them.

Exam list, subject weights and negative-marking values live in `content/taxonomy.json`; adding a new exam means
adding one entry there.

### What's covered vs intentionally out of scope

Covered: the **common/general syllabus** — the sections shared across candidates for each exam, verified against
the published subject patterns for RRB NTPC (CEN 01/2019), RRB Group D (CEN 02/2018), RRB ALP & Technician
(CEN 01/2018), RRB JE (CEN 03/2018), RPF Constable/SI (CEN 01-02/2018 and successors), and DFCCIL
Executive/Junior Executive's CBT1 (see `docs/RAILWAY_EXAMS_RESEARCH.md` for the DFCCIL sourcing and for the
full survey of every other railway exam/process considered — RRB SSE, Ministerial & Isolated Categories, RRC,
other railway PSUs (IRCON, RVNL, RITES, CONCOR, IRCTC) and metro rail — and why each was or wasn't added).
None of these exams' written CBT includes a separate English-language section — RailPariksha still ships 26 English questions as
clearly-labelled **bonus practice** (visible in the Practice tab regardless of which exam is selected, since many
aspirants also prepare for SSC/banking exams that do test English), but English is deliberately not attached to
any exam's official subject list in `taxonomy.json`, so its presence never misrepresents what's actually tested.

Deliberately out of scope for now, and why:
- **Trade/discipline-specific technical papers** — RRB ALP/Technician CBT2 Part B (per ITI trade: Fitter,
  Electrician, Electronics Mechanic, Wireman, Diesel Mechanic, etc. — dozens of trades) and RRB JE CBT2's
  discipline-specific technical section (Civil/Mechanical/Electrical/Electronics & Communication). Authoring
  these with real accuracy needs subject-matter expertise per trade; getting a technical fact wrong is worse
  than not covering it. A future pass could add the 4-5 most common JE disciplines and ALP trades if there's
  demand.
- **Paramedical category-specific professional papers** — RRB Paramedical CBT2's subject-specific paper (per
  category: Staff Nurse, Pharmacist, Lab Technician, ECG Technician, etc.) is medical/clinical knowledge, which
  carries real-world stakes if wrong. Only the common CBT1 syllabus (Maths, Reasoning, Science, GK, Current
  Affairs) is covered.
- **Physical Efficiency/Measurement Tests (RPF), typing tests and CBAT** (NTPC Station Master) — these are
  skill/physical tests, not written MCQ content, so there's nothing to build here.
- **RRB "Ministerial and Isolated Categories" postings** (Stenographer, Junior Translator, Chief Law Assistant,
  Staff Car Driver, Cost Accountant, Editor, etc.) — a single CBT, but half its marks (Professional Ability) are
  a different, unrelated syllabus per post (shorthand for Stenographer, translation theory for Junior
  Translator, motor-vehicle rules for Staff Car Driver, law for Chief Law Assistant...), so there's no one
  coherent "MI" mock test to build, unlike Paramedical where every category shares the same common CBT1; niche,
  low-volume recruitment either way.
- **RRB Senior Section Engineer (SSE)** — its CBT mixes a 90-of-150-question discipline-specific technical
  section (Part B) directly into the same scored test as the general section (Part A), rather than as a
  separable later stage the way JE's CBT2 is — so, unlike JE, there's no way to build an SSE entry that covers
  a meaningful share of the real exam without the same per-discipline technical-accuracy risk already flagged
  above.
- **Railway PSUs other than DFCCIL** (IRCON, RVNL, RITES, CONCOR, IRCTC) — IRCON, RVNL and RITES have no
  publicly sourced, consistent question-count split for their general sections; CONCOR's CBT is half
  discipline-specific Professional Knowledge (same reasoning as the technical papers above); IRCTC's regular
  recruitment is merit-based with no written exam at all. DFCCIL is the one PSU covered — its CBT1 has a
  specific, consistently-reported section-by-question breakdown that maps cleanly onto subjects this app
  already has (see `docs/RAILWAY_EXAMS_RESEARCH.md`).
- **RRC (Railway Recruitment Cell) processes** — RRC-run Level 1 recruitment uses the exact same CBT and
  syllabus as `rrb_group_d` (RRCs just administer it per zone), so it's not a distinct exam to add; RRC Act
  Apprentice recruitment has no written test at all (selection is by Class 10 + ITI marks only).
- **Metro Rail corporations** (DMRC, Mumbai Metro/MMRC, Bangalore Metro/BMRCL, Chennai Metro, etc.) — commonly
  searched alongside "railway exams" by aspirants, but legally separate state/UT corporations, not Indian
  Railways; not recruited into by RRB/RRC/RPF. This app's Railway GK content (zones, Kavach, RRB/RPF structure)
  is Indian-Railways-specific and doesn't transfer to a metro corporation's syllabus. DMRC is the most
  prominent (and does run a well-documented CBT of its own) so it would be the obvious first candidate if this
  app's scope ever deliberately broadens beyond Indian Railways — but that's a branding/positioning decision
  for later, not something to fold in silently now.

## Subjects & why each exists

- **Maths** and **General Intelligence & Reasoning** — the two subjects common to every RRB/RPF CBT.
- **General Science** — RRB Group D/ALP/Technician/JE/Paramedical staple (physics/chemistry/biology basics,
  human body, everyday science, inventions).
- **General Awareness (GK)** — static GK: polity, history, geography, economy, awards, books & authors, important
  days, sports, environment & ecology, art & culture — all explicitly named in RRB's own "General Awareness"
  syllabus wording.
- **Current Affairs** — separately from GK because it needs a live pipeline (see below), not a fixed bank.
- **Railway General Knowledge** — RailPariksha's differentiator versus generic GK apps: zones, gauges, notable
  trains, safety systems like Kavach, RRB/RPF's own structure. Real aspirants are tested on this and it is
  under-served by other apps.
- **Computer & Financial Awareness** — RRB NTPC/JE specific.
- **English** — bonus practice only; see "What's covered vs intentionally out of scope" above for why it isn't
  tied to any exam's official subject list.

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

- [x] Taxonomy (8 subjects incl. Environment/Culture GK topics, 9 exams incl. ALP/Technician split and DFCCIL
      Executive/Jr. Executive), starter
      question bank grown to 40-46 per core subject (maths, reasoning, science, gk, railway_gk), 26 each for
      computer and the bonus English set, flashcards, motivation, 10 topic notes/mind-maps across 4 subjects.
- [x] Flutter app re-skinned from Bharari's proven architecture: navy/gold "Indian Railways" theme, train-class
      level progression (General → Sleeper → AC 3-Tier → AC 2-Tier → Rajdhani), Hindi/English throughout, a
      bonus-practice entry point for content (English) that isn't tied to any exam's syllabus.
- [x] CI (`railpariksha_ci.yml`), release (`railpariksha_release.yml`), content-pack build
      (`railpariksha_content_pack.yml`), daily current-affairs draft (`railpariksha_current_affairs.yml`).
- [ ] Notes/mind-maps for the remaining topics without one yet (10 of the taxonomy's ~65 topics have a note so
      far; the rest fall back to the honest "coming soon" empty state).
- [ ] Consider the 4-5 most common JE disciplines / ALP trades for a future technical-paper pass, if there's
      demand — see "What's covered vs intentionally out of scope" above.
- [ ] Wire a real hosting target for `content.json` (see `docs/LAUNCH.md` §4) so the app can update its question
      pack without a Play Store release.
- [ ] Store listing, screenshots and the account/signing steps in `docs/LAUNCH.md`.
