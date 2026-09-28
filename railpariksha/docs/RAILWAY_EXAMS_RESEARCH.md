# Railway recruitment exams — exhaustive research (Sept 2026)

This document is the research trail behind the "no stone left unturned" pass over Indian Railways
recruitment exams. For every exam/process found, it records: conducting body, whether it's a written
MCQ-based exam at all (vs. skill/interview/merit-only), the current published pattern with sources, and
whether it's already in `content/taxonomy.json` — with a recommendation (add / skip) for anything that
wasn't.

Only exams that are (a) real and currently run, (b) genuinely MCQ/CBT-based, and (c) have a publicly
verifiable pattern get added. Everything else is recorded here with its reasoning so the decision is
never silent.

## 1. RRB (Railway Recruitment Board) exam categories

| Category | Written CBT? | Already in taxonomy.json? | Verdict |
|---|---|---|---|
| NTPC (UG/Graduate) | Yes | Yes (`rrb_ntpc`) | No change — CBT1 is confirmed common for UG and Graduate levels alike in the 2024-25 cycle, so one combined entry is correct, not a gap.¹ |
| Group D | Yes | Yes (`rrb_group_d`) | No change |
| ALP (Assistant Loco Pilot) | Yes (CBT1/CBT2 common stage) | Yes (`rrb_alp`) | No change |
| Technician Gr.1/Gr.3 | Yes | Yes (`rrb_technician`) | No change |
| Junior Engineer (JE) | Yes (CBT1 common; CBT2 has a discipline-specific technical paper) | Yes (`rrb_je`, CBT1 only) | No change |
| Senior Section Engineer (SSE) | Yes, but the CBT itself is Part A (60Q general: GA/Reasoning/Arithmetic, undivided) + **Part B (90Q, technical, per discipline)** — i.e. 60% of the *same* CBT is discipline-specific technical, not a separable later stage like JE's CBT2.² | No | **Skip.** Because the technical section is mixed directly into the scored CBT (not a later optional stage), there is no way to build an "SSE common-syllabus" exam entry without either misrepresenting 60% of the real question count or inventing technical content per engineering discipline — the same subject-matter-expertise risk already flagged for JE CBT2/ALP trade papers in the existing scope-out. |
| Paramedical categories (Staff Nurse, Pharmacist, Lab Technician, ECG Technician, etc.) | Yes (common CBT1 + category-specific professional CBT2) | Yes (`rrb_paramedical`, common portion only, flagged as an estimate) | No change |
| Ministerial & Isolated Categories (Junior Stenographer Hindi/English, Junior Translator, Chief Law Assistant, Staff Car Driver, Cost Accountant, Editor, etc.) | Yes — single CBT, 100Q/100 marks, split roughly 50 marks "Common Subjects" (Maths/Reasoning/GS/GA — Reasoning alone confirmed at 15Q, others not broken out precisely) + 50 marks "Professional Ability" (post-specific).³ | No | **Skip, confirmed.** Two independent reasons: (a) the Professional Ability half is a different, unrelated syllabus for *each* post (shorthand/typing conventions for Stenographer, translation theory for Junior Translator, motor-vehicle/traffic rules for Staff Car Driver, law for Chief Law Assistant, accountancy for Cost Accountant) — there is no single coherent "MI mock test" that would actually serve any one of these aspirants, unlike Paramedical where every category shares one common CBT1 the app already covers; (b) even the "Common Subjects" 50-mark split isn't published beyond the Reasoning sub-count, so weighting it would mean guessing. Matches this app's existing documented scope-out. |
| RRB apprentices (Act Apprentice via RRB-notified quota) | **No** — merit-based on Class 10 + ITI marks only, no written test or interview.⁴ | N/A | Not applicable — there is no MCQ content to build. |

¹ [RRB NTPC Exam Pattern 2026](https://testbook.com/rrb-ntpc/exam-pattern) — "CBT 1 is common for all notified posts of RRB NTPC (Graduate and Undergraduate)."
² [RRB SSE Syllabus & Exam Pattern](https://testbook.com/rrb-sse/syllabus-exam-pattern), [RRB SSE Exam Pattern — RRBApply](https://rrbapply.com/rrb-sse-exam-pattern/) — Part A 60Q (GA/Reasoning/Arithmetic) + Part B 90Q (Technical), 150 total, 1/3 negative marking.
³ [RRB Ministerial and Isolated Categories Syllabus — PW](https://www.pw.live/railway/exams/rrb-ministerial-and-isolated-categories-syllabus-details), [prepp.in MI syllabus & pattern](https://prepp.in/rrb-ministerial-and-isolated-categories-exam/syllabus-and-exam-pattern) — 100Q/100 marks, Common Subjects 50 + Professional Ability 50, Reasoning confirmed at 15Q within Common Subjects.
⁴ [RRC NR Apprentice Exam Pattern & Selection](https://sarkariresultbook.com/rrc-nr-apprentice-exam-pattern-syllabus-2025/) — "Act Apprentices recruitment... is a merit-based recruitment with no written exam."

## 2. RPF (Railway Protection Force) exam categories

Searched specifically for categories beyond Constable/SI (Ancillary, SI-promotion exams, etc.).
Finding: **direct-recruitment open CBTs under RPF are just Constable and SI** — both already covered
(`rpf_constable`, `rpf_si`). "RPF (Ancillary)" and Sub-Inspector *promotions* (SI → Inspector → Circle
Inspector → Zonal Inspector → Dy. Superintendent) are internal departmental promotions for serving RPF
staff, not open recruitment exams with a public MCQ syllabus — nothing to add here.⁵

⁵ [RPF SI Career Progression — SPLessons](https://splessons.com/lesson/rpf-si-career-progression/), [RPF SI Syllabus & Exam Pattern — Testbook](https://testbook.com/rpf-si/syllabus-exam-pattern).

## 3. RRC (Railway Recruitment Cell) processes

RRCs are the zone-level bodies that actually run **Level 1 (Group D)** recruitment on RRB's behalf (the
CEN is issued centrally, RRCs handle it per zone) and **Act Apprentice** recruitment under the
Apprentices Act.

- **RRC Level 1 recruitment**: same CBT, same syllabus, same pattern as `rrb_group_d` already in
  taxonomy.json — it is not a distinct exam, just a different administrative body running the same test.
  No separate entry needed.
- **RRC Act Apprentice**: confirmed **no written exam or interview at all** — selection is purely on Class
  10 marks + ITI trade marks.⁴ Nothing to build.

Conclusion: RRC processes do not need (and would be actively wrong to add as) separate taxonomy entries.

## 4. Railway PSUs with their own recruitment (outside RRB/RRC)

| PSU | Runs its own written MCQ exam? | Pattern found | Already covered | Verdict |
|---|---|---|---|---|
| **DFCCIL** (Dedicated Freight Corridor Corporation) | Yes — CBT1 (common, all posts) then CBT2 (post-specific, often technical) | CBT1: **100Q** — Mathematics/Numerical Ability 30, Logical Reasoning/General Intelligence 30, General Awareness 15, General Science 15, Knowledge about Railways/DFCCIL 10. Negative marking 0.25/wrong answer.⁶ | No | **Add.** The CBT1 (the stage every applicant sits, before any post-specific technical CBT2) has a specific, consistently-reported section-by-question breakdown that maps cleanly onto this app's existing subjects (maths, reasoning, gk, science, railway_gk) — no new subject or new content needed. |
| **IRCON International** | Written test exists for some direct-recruitment drives (Works Engineer etc.) — GK/Reasoning/GA/Aptitude, ~200 marks | Multiple sources agree on subject *names* (GK, Reasoning, GA, Aptitude) but **no source gives a consistent section-wise question/marks split**, and IRCON's senior technical hiring is mostly via GATE score or campus placement, not a standing open CBT.⁷ | No | **Skip — insufficient public detail to weight confidently.** Would have to guess proportions; not worth the risk of a fabricated split. |
| **RVNL** (Rail Vikas Nigam) | Rarely — most RVNL hiring is senior/technical (GATE-score based) or interview-only; no stable, publicly documented MCQ CBT pattern was found.⁸ | — | No | **Skip — no confirmed written MCQ pattern exists to source.** |
| **RITES Limited** | Yes for Management Trainee/Assistant Manager grades — general section (QA, Reasoning, English, GK) + a discipline-specific technical section, interview carries real weight (written test is only ~60% of final selection) | General-section topics are listed by multiple sources but **no official question-count split** was found, and roughly half the paper is discipline-specific technical content per post (Civil/Mechanical/Electrical/Finance/etc.)⁹ | No | **Skip.** Same two problems as IRCON (no sourced split) plus the same discipline-specific-technical risk already excluded for JE/ALP/SSE — and it's a small, graduate-entry-grade recruitment with limited overlap with this app's aspirant base. |
| **CONCOR** (Container Corporation of India) | Yes, for Management Trainee — CBT is 100Q: Professional Knowledge 50 (post/discipline-specific), English 10, Reasoning 10, Quantitative Aptitude 15, General Knowledge 15.¹⁰ | Yes, and unusually well-sourced with an exact split | No | **Skip.** Even though the *split* is well documented, half the real exam (Professional Knowledge) is discipline-specific technical/professional content this app deliberately doesn't build (same reasoning as JE/ALP technical papers and Paramedical's professional paper) — building only the non-technical 50 marks would materially misrepresent what CONCOR's CBT actually tests, and it's a small graduate-entry PSU exam, not core RRB/RPF-aspirant territory. |
| **IRCTC** | **No** — IRCTC's regular (Apprentice Trainee) recruitment is explicitly **merit-based on Class 10 marks, no written exam or interview**.¹¹ Other IRCTC posts (small-scale, senior) have no standing public CBT pattern. | — | N/A | **Skip — nothing to build.** |

⁶ [DFCCIL CBT 1 Exam Pattern — Byjus](https://byjus.com/govt-exams/dfccil-syllabus/), corroborated by [Testbook DFCCIL Executive syllabus](https://testbook.com/dfccil-executive/syllabus-exam-pattern) and [Careerpower DFCCIL syllabus](https://www.careerpower.in/dfccil-syllabus.html) (100Q/90 min, 0.25 negative marking; section list and counts consistent across sources).
⁷ [Quora — IRCON campus recruitment pattern](https://www.quora.com/What-is-the-exam-pattern-and-syllabus-of-IRCON-campus-recruitment-in-NIT-Kurukshetra-EEE-and-the-process-of-selection), [Freshersnow IRCON syllabus](https://www.freshersnow.com/ircon-syllabus/).
⁸ Searched directly; no dedicated syllabus/pattern page exists comparable to RRB/RPF/DFCCIL/CONCOR — RVNL recruitment notices for engineers point to GATE-score-based shortlisting or interview, not an RVNL-run CBT.
⁹ [RITES Exam Pattern — PW](https://www.pw.live/ae-je/exams/rites-exam-pattern), [RITES Assistant Manager Selection Process](https://financecareer.in/blog/ritesassistantmanagerfinanceselectionprocess2026exampatternpaperpatterninterview) — written test is 60% weight, interview 40%; no official question-count table found.
¹⁰ [CONCOR MT Syllabus and Exam Pattern — Testbook](https://testbook.com/concor-management-trainee/syllabus-exam-pattern).
¹¹ [IRCTC Recruitment 2025 — PW](https://www.pw.live/railway/exams/irctc-recruitment) — "selection process for IRCTC Apprentice Trainees is merit-based, and no written exams or interviews will be conducted."

## 5. Metro Rail corporations (DMRC, MMRC, BMRCL, Chennai Metro, etc.) — explicit scope decision

**Decision: metro rail stays out of scope, including DMRC.** Reasoning, spelled out rather than left
implicit:

- Metro corporations (DMRC = Delhi Metro Rail Corporation, and equivalents for Mumbai/Bangalore/Chennai)
  are separate companies incorporated under the Companies Act, jointly owned by the Union and the
  relevant state government — they are **not** part of Indian Railways, don't report to the Railway
  Board, and aren't recruited into by RRB/RRC/RPF. "Railway exam" aggregator sites bundle them in because
  aspirants cross-prepare, not because they're the same employer.
- This matters concretely for RailPariksha's content: the app's differentiator subject, **Railway GK**
  (zones & divisions, gauges, Kavach, RRB/RPF's own structure, Railway Board/recruitment machinery), is
  specific to Indian Railways and simply doesn't apply to a metro corporation's syllabus — a DMRC exam
  entry would either need a parallel "Metro GK" subject (zones don't exist for a single-city metro; the
  real DMRC-specific content is rolling stock, signalling standards, safety codes) or would misleadingly
  attach Indian-Railways trivia to a metro exam.
- DMRC *does* run its own well-documented CBT (Paper 1: ~120Q General Awareness/Reasoning/Quantitative
  Aptitude + discipline/trade knowledge; Paper 2: ~60Q, mostly General English for some posts),¹² and is
  by far the most prominent/most-searched metro exam, so if this app's scope ever explicitly broadens
  beyond Indian Railways it is the obvious first candidate — but that's a deliberate branding/positioning
  decision for a future call, not something to fold in silently now.
- **Verdict: skip all metro corporations for now**, DMRC included, on identity grounds (not part of
  Indian Railways) as much as content-fit grounds (Railway GK doesn't transfer).

¹² [DMRC Syllabus 2025 — Adda247](https://www.adda247.com/engineering-jobs/dmrc-syllabus/), [DMRC JE Exam Pattern — ZoneTech](https://zonetech.in/dmrc-je-exam-pattern).

## Summary of changes made to taxonomy.json

| Exam added | Group | Subjects reused | New content needed? |
|---|---|---|---|
| DFCCIL Executive / Junior Executive (CBT1, common stage) | new group `psu` | maths (30), reasoning (30), gk (15), science (15), railway_gk (10) | No — all five subjects already have question banks; only the taxonomy entry + `psu` exam_group were added. |

Everything else researched above is a deliberate skip, with the reasoning recorded next to it. No new
subjects were added to `taxonomy.json` this pass — every exam that cleared the bar for inclusion (DFCCIL)
maps entirely onto subjects the app already has content for.
