# MahaPariksha (working name) — Company Plan v2
Android-first · maximum automation · every step has a fallback · realistic numbers

## Context
You are one founder running this as a company. The audience is Marathi-medium government-exam aspirants, mostly on ₹8–15k Android phones with patchy data. The repo is empty. This plan covers: the name, what it will really cost (including Claude tokens), the probability of success, the automated operating system, fallbacks, the timeline and kill criteria. Numbers are estimates as of Sep 2026 at ₹88/$. Claude API prices come from Anthropic's current price list.

---

## 0. Name check — result: do NOT launch as "MahaPariksha"
Findings:
- **mahapariksha.gov.in is the Maharashtra government's own exam portal** (MAHA IT). It carries a bad reputation from the exam irregularities around 2019–21. Using the name risks:
  1. rejection under Google Play's **impersonation/government-affiliation policy**;
  2. aspirants assuming you are the government, or linking you to the scandal;
  3. no chance of ranking in search against a .gov.in site.
- An existing Play app, **"Mahapariksha – Free Test Series"** (package `com.mahapariksha.test`, by eStudy7), already uses the name.
- Domains: mahapariksha **.com / .in / .co.in are taken**; only .app appears free.

**Recommendation:** keep "MahaPariksha" as the internal/repo name only. Pick a public brand.

### Candidate check (RDAP domain lookups, web and Play searches)
| Brand | .com / .in / .app | Conflicts found | Verdict |
|---|---|---|---|
| **ParikshaMaha** | all free | Reversal of the government "MahaPariksha" name. "Sounds like an official testing board" is exactly what Google Play's **impersonation/government-affiliation policy** rejects. Users will also confuse it with the scandal-hit portal. | ❌ High policy risk |
| **Lakshya Maharashtra** | all free | **Lakshya IAS Academy**: Maharashtra, UPSC/MPSC/Group C coaching since 2002, 6+ branches, has a Play app. **"MPSC Lakshya"**: YouTube channel + app. PhysicsWallah's "Lakshya" batches. Same services in the same state creates real **trademark opposition risk (class 41)**, and you'd be buried in Play search. | ⚠️ Legal/ASO risk |
| **BhartiSarav** (भरती सराव) | all free | None found | ✅ Ownable, and it is the keyword itself |
| LakshyaSarav / YashSarav | all free | "Lakshya" is still crowded / generic | Backup |

### Market research: how the category names itself
- The Play Store category is flooded with **generic keyword names** from small developers: "Police Bharti Exam Preparation" (mkinfo), "Talathi Bharti Exam Prep", "पोलीस भरती स्टडी", "Police Bharti Question Paper", "Dream Khaki Vardi". None of them is a brand, so none earns trust. **The gap is a real brand plus a keyword-rich title.**
- Coaching brands already hold the emotional words: **Jidd** Career Academy (Pune, Police Bharti), **Lakshya** IAS Academy, MPSC **Dhyas** Academy, **Study Katta**. Avoid those words.
- Testbook sells a Marathi Police test series (35k+ students), so the national players are already here. A differentiated, trustworthy local brand matters.
- Trademark note: purely descriptive names (e.g. BhartiSarav = "recruitment practice") are **weak or unregistrable trademarks**. A meaningful everyday word used in a new context (e.g. Nivad) is registrable and defensible.

### Top 5 recommended names
| # | Brand | Meaning / hook | Domains (RDAP) | Conflicts | Play title example |
|---|---|---|---|---|---|
| 1 | **Nivad (निवड)** ⭐ | "Selection". Every aspirant's end goal ("माझी निवड झाली!" = "I got selected!"). Fits Police, Talathi, Rajyaseva and RTO alike. Short and memorable. | nivad.in ✅ nivad.app ✅ (.com taken → nivadapp.com ✅) | None found | "Nivad: Police Bharti, Talathi Test" |
| 2 | **Kasoti (कसोटी)** | "Test / trial of worth". Premium, serious tone. | kasoti.app ✅, kasotiapp.com/.in ✅ (.com/.in taken) | Needs a trademark search | "Kasoti: MPSC, Police Bharti Sarav" |
| 3 | **Uttirna (उत्तीर्ण)** | "Passed". Outcome-focused. | uttirna.app ✅, uttirnaapp.com/.in ✅ | Needs a trademark search | "Uttirna: Bharti Sarav Test" |
| 4 | **BhartiSarav (भरती सराव)** | "Recruitment practice". Exact search keyword. | .com/.in/.app all ✅ | None, but a weak trademark | "BhartiSarav: Police, Talathi" |
| 5 | **LakshyaSarav** | Keeps your "Lakshya" idea. | .com/.in/.app all ✅ | Close to Lakshya IAS Academy / MPSC Lakshya | "LakshyaSarav: MPSC, Bharti" |

(Round 1 pick was Nivad; it's superseded by Round 2 → **Jinku**.) It speaks the aspirant's own language of success, is legally ownable, covers every exam, and gets keyword reach from the Play title.

### Round 2 — catchy, motivating, pumping-up (founder's brief)
| # | Brand | Energy | Domains (RDAP) | Conflicts | English spelling |
|---|---|---|---|---|---|
| 1 | **Jinku (जिंकू!)** ⭐ | "We'll win!" A rallying cry that echoes the classic "जिंकून दाखवू" ("we'll win and show them"). Users shout it; streak and rank screens can say "Aaj pan jinku!" ("We'll win today too!"). | jinku.in ✅ jinku.app ✅ jinkuapp.com ✅ (+ jinkoo.in/.app ✅ as a typo catch; jinku.com taken) | None found in the category | ✅ simple |
| 2 | **Bharari (भरारी)** | "Soaring flight" ("उंच भरारी" = "fly high"). Aspirational lift. | bharari.app ✅ bharariapp.com/.in ✅ | None found | ✅ |
| 3 | **Garja (गर्जा)** | "Roar!", from "गर्जा महाराष्ट्र माझा" ("Roar, my Maharashtra"). State pride plus pump. | garja.app ✅ garjaapp.com/.in ✅ | None found; anthem association (positive) | ✅ |
| 4 | **Dhadak (धडक)** | "Charge / strike". Pure hustle. | dhadak.app ✅ dhadakapp.com ✅ | ⚠️ Bollywood film "Dhadak" (Dharma), possible trademark clash | ✅ |
| 5 | **Nivad (निवड)** | "Selection". Calmer, outcome-focused. | nivad.in/.app ✅ | None | ✅ |

**FINAL DECISION: Bharari** (founder's choice; see 11b). Earlier analysis kept for the record. Jinku: it's a two-syllable battle cry, one obvious English spelling, registrable, with .in and .app free. It gives the whole product a voice: "Jinku Streak", "Jinku Mock", "Jinku Rank". Play title: `Jinku: Police Bharti & Talathi`.

### English-search reality (users search in English/romanized text)
Most aspirants' phones are set to English, so Play shows the **en-IN listing**. They type "police bharti", "talathi bharti", "mpsc test", "police bharti question paper". So:
- **The brand must pass a "hear it once, type it right" test in English.** Nivad ✅ (one obvious spelling; "niwad" is a rare variant) · Kasoti ⚠️ ("kasauti" variant) · Uttirna ❌ (uttirn/uttirna/utirna; dropped) · BhartiSarav ⚠️ (bharti/bharati).
- **Listing setup:** the default listing is **en-IN** with English keywords, plus a **mr-IN** localized listing in Marathi for Marathi-language phones.
  - Title (30 chars): `Nivad: Police Bharti & Talathi`
  - Short description (80 chars): `Police Bharti, Talathi, MPSC mock tests & PYQ in Marathi. Free daily quiz.`
  - Full description: naturally repeat "police bharti 2026", "talathi bharti", "mpsc", "zp bharti", "question paper", "marathi" (Play indexes it; no stuffing).
- Tag the app with the Education category plus relevant tags. Screenshots with Marathi UI and English captions.
- Brand-name search matters for word of mouth and repeat users ("Nivad app"). Keyword search matters for discovery. The title covers both.

**About Play Store keywords:** the brand name doesn't need to carry the keywords. The 30-character Play title and the short description do. Example title: **"BhartiSarav: Police Bharti, Talathi"**, with the short description: "पोलीस भरती, तलाठी, MPSC सराव — मोफत टेस्ट" ("Police Bharti, Talathi, MPSC practice — free tests"). This works with any brand. So pick the brand for **ownability and trust**, and get search ranking from the title.

Before committing, verify at a registrar, search IP India trademarks (classes 9 and 41) and search the Play Store. Then register the domains (~₹2.5k/yr) and file the trademark (₹4.5k per class as an individual/MSME). Always show "Not affiliated with any Government body" in the listing and in the app.

---

## 1. Probability of winning (honest)
Base rate: most solo edtech apps never reach 10k monthly active users (MAU). Your edges are lower cost than competitors, a Marathi-first niche, an automated content engine and trust-based positioning. Your biggest risks are distribution and a wrong-answer incident.

| Year-1 outcome | Definition | Probability |
|---|---|---|
| Fail | Under 5k MAU; never covers costs; shut down or pivot | **~45%** |
| Survive | 10–30k MAU; ₹2–10L revenue; roughly break-even | **~33%** |
| Solid | 30k–1L MAU; ₹10–50L ARR; hire #1 feasible | **~17%** |
| Breakout | 1L+ MAU; ₹1Cr+ ARR (your year-2 expansion gate) | **~5%** |

**What moves the odds most, in order:**
1. **Launching before a big exam notification wave** (Police Bharti or Talathi). Launching into an active cycle can roughly double outcomes.
2. **Telegram audience built before the app launches.** Starting with 5k+ subscribers moves the Fail odds from about 45% to about 30%.
3. **Report rate under 1 per 1,000 attempts.** A single viral "this app has wrong answers" post can kill a trust brand.
4. **B2B abhyasika pilots.** These are the most certain revenue and do not depend on consumer conversion.

---

## 2. Claude API token costs (detailed)
Prices: Sonnet 5 $2/$10, Haiku 4.5 $1/$5, Opus 5.5 $4/$20 per million tokens (input/output). The Batch API is 50% off. Cache reads cost about 10% of the input price.
Assumption: Marathi (Devanagari) uses roughly 2–3× as many tokens as English. One MCQ with 4 options plus an explanation is about 350–450 output tokens.

### 2a. One-time library build — target 40k live questions (generate ~60k, expecting about a third to be rejected)
| Step | Model | Tokens per question (in/out) | Batch cost per Q | × Volume | USD | ₹ |
|---|---|---|---|---|---|---|
| PYQ OCR cleanup and structuring | Haiku 4.5 | 800 / 400 | $0.0014 | 20k PYQs | $28 | 2.5k |
| Question generation (10 per call, cached syllabus and examples) | Sonnet 5 | 300 / 420 | $0.0024 | 60k | $144 | 12.7k |
| Verification pass 1 (blind solve, adaptive thinking) | Sonnet 5 | 450 / 900 | $0.0047 | 60k | $282 | 24.8k |
| Verification pass 2 (fact, ambiguity and language check) | Haiku 4.5 | 600 / 500 | $0.0016 | 60k | $96 | 8.4k |
| Tie-breaker (only where the passes disagree, ~15%) | Opus 5.5 | 800 / 1500 | $0.0158 | 9k | $142 | 12.5k |
| Calibration runs on the anchor PYQs (×3) | same pipeline | — | — | 6k | $40 | 3.5k |
| Prompt iteration and re-runs buffer (+30%) | — | — | — | — | $220 | 19.4k |
| **Total library** | | | | | **~$950** | **~₹84k** |

Your earlier estimate was ₹27–45k. That holds only for a smaller first release (Police + Talathi, about 15k questions, **~₹32k**). **Plan:** build in phases. Phase 1 is Group C at about ₹32k; Rajyaseva and RTO come later from revenue.

### 2b. Ongoing monthly API cost
| Job | Volume per month | ₹ per month |
|---|---|---|
| Daily current affairs (15 questions/day, generate + 2 verifications, not batched because it's daily) | 450 | ~₹500 |
| Library expansion or refresh | 3–5k questions | ₹4–7k |
| Re-verification of reported questions | ~300 | ~₹300 |
| Scripts for YouTube Shorts and Telegram posts | 60 | ~₹200 |
| Monthly calibration check | 2k | ₹1k |
| **Total API** | | **₹6–9k/month** (₹1.5k in quiet months with expansion paused) |

### 2c. Your Claude subscription (for building)
Max plan ($100, about ₹10.5k incl. GST) during the 4 build months, then Pro ($20, about ₹2.1k).

---

## 3. Full company cost model — Year 1

### 3a. One-time (months 0–4)
| Item | ₹ |
|---|---|
| Content library, Phase 1 (Group C) | 32,000 |
| Phase 2 (Rajyaseva + RTO), month 6+ | 52,000 |
| PYQ books (K'Sagar etc.) | 5,000 |
| Google Play developer account ($25) | 2,200 |
| Closed-test tester service (~$30–50) | 4,000 |
| Domains (.com/.in/.app) | 2,500 |
| Trademark (2 classes, individual/MSME) | 9,000 |
| Legal: privacy policy, terms, refund policy (template + lawyer review) | 7,000 |
| Low-end Android test phone (2–3 GB RAM) | 8,000 |
| App icon, Play listing graphics (freelancer) | 5,000 |
| Business registration: sole proprietorship + Udyam + current account (Pvt Ltd deferred to fundraise/hire) | 2,000 |
| **One-time total** | **~₹1.29L** |

### 3b. Monthly recurring
| Item | Build months (1–4) | Live months (5–12) |
|---|---|---|
| Claude subscription | 10,500 | 2,100 |
| Claude API (ongoing) | 1,000 | 7,000 |
| Supabase (Free → Pro $25) | 0 | 2,200 |
| Firebase (FCM, Crashlytics, Analytics) | 0 | 0 |
| Phone OTP via MSG91 (optional; Google sign-in is free) | 0 | 1,000 |
| GitHub Actions (cron jobs) | 0 | 0 |
| Monitoring/alerts (free tiers: UptimeRobot, Sentry) | 0 | 0 |
| Accountant / GST filing | 0 | 1,500 |
| Marketing: posters, abhyasika visits, referral prizes | 0 | 8,000 |
| Misc (Google Workspace email, tools) | 500 | 500 |
| **Monthly** | **~₹12k** | **~₹22k** |

### 3c. Year-1 total
One-time ₹1.29L + (4 × ₹12k) + (8 × ₹22k) + 15% contingency ≈ **₹4.0L**.
**Lean version: ~₹2.3L.** Skip the Phase-2 library until revenue exists, keep Claude on Pro, cut marketing to ₹3k/month, and skip OTP and the trademark until traction. This is the version to start with.

### 3d. Variable costs on revenue (unit economics)
- **Google Play service fee:** 15% on in-app digital purchases (the first $1M per year). User-choice billing lowers this by about 4 points.
- **Razorpay** (web/UPI checkout, where policy allows): about 2%.
- **GST:** 18% applies once revenue crosses ₹20L/year (register earlier voluntarily if B2B clients need invoices).
- A **₹199 pass** nets about **₹143** (₹199 ÷ 1.18 GST × 0.85 Play fee). Without GST registration it nets ₹169.

---

## 4. Revenue model and break-even
Assumptions per 10k MAU:
| Stream | Assumption | ₹ per month per 10k MAU |
|---|---|---|
| Rewarded ads | 8 views/user/month × eCPM ₹40 | ~3,200 |
| Exam Pass | 1.5% buy per month, ₹160 net | ~24,000 (in exam season; about 1/3 of that off-season) |
| Book affiliate (Dnyandeep, fallback Amazon) | 0.5% buy a ₹400 book at 10–15% | ~2,500 |
| B2B abhyasika | 5 centres × ₹1,000 (independent of MAU) | 5,000 |

**Break-even (₹22k/month):** about 8–10k MAU in exam season and about 20k off-season. The realistic target is month 8–12, and only in the Survive-or-better scenarios.
Ads alone never pay the bills. The Pass and B2B are the business.

---

## 5. Tech stack (Android-first, solo-friendly)
| Layer | Choice | Fallback |
|---|---|---|
| App | Flutter, Android 8+, AAB under 15 MB, question packs downloaded not bundled | — |
| Offline | SQLite (drift) on device; attempts sync in batches | — |
| Backend | Supabase (Postgres, Auth, Storage, Edge Functions) | Self-host on a ₹1.5k/month VPS |
| Auth | Anonymous device ID first, then Google sign-in; phone OTP later | — |
| Pipelines | Python on GitHub Actions cron | VPS cron |
| Human review | **Telegram bot** with ✅/❌/✏️ buttons (works from your phone) | Supabase table editor |
| Push | FCM | Telegram channel |
| Payments | Google Play Billing one-time products (policy-safe) | Razorpay UPI via web checkout / user-choice billing |
| Ads | AdMob rewarded only | Unity/AppLovin via mediation |
| Analytics | Firebase + Crashlytics | PostHog |

Android specifics: test on a 2 GB RAM phone, Noto Sans Devanagari font, low-data mode, dark mode, large-text support, resume-after-kill in tests, and a Marathi Play listing.

---

## 6. Data model (state-parameterized)
`state → exam → section → subject → topic → subtopic → difficulty_tier`
Key tables: `questions` (lang, stem, options, correct_idx, explanation, source_type, source_ref, confidence, verify_1, verify_2, status: draft/flagged/live/killed, report_count, attempt_count, correct_rate), `exam_topic_weight`, `pyq_anchor`, `reports`, `attempts`, `passes` (a one-time purchase with `valid_until`; no renewal), `centres` (B2B), `ca_items`.

---

## 7. Automation system — about 95% runs itself
| Job | Trigger | What it does | Human part | Fallback if it fails |
|---|---|---|---|---|
| Library generator | Manual/batch | PYQ-styled generation → 2 verifications → tie-breaker → live or flagged | Approve the topic graph once per exam | PYQ-only mode for that topic |
| Calibration | Monthly cron | Runs the verifier on known-answer PYQs and reports its error rate | Read the report | If error is above 2%, tighten the threshold and pause generation |
| Daily current affairs | 06:00 IST cron | PIB + DGIPR RSS → Maharashtra filter → 15 MCQs → verify → Telegram review queue | ~10 min of taps | Unreviewed by 10:00 → publish only items both passes agreed on, with a source link |
| Publisher | On approval | App + push notification + Telegram channel + YouTube Shorts (FFmpeg render + API upload) | None | Any single channel failing doesn't block the others; you get an alert |
| Exam-notice watcher | Hourly cron | Diffs MPSC/Mahapolice/RDD/Mahabhumi pages → drafts an alert | One-tap confirm | None; false alerts never auto-send |
| Quality guard | Real-time | 2 reports or a correct-rate anomaly → auto-hide → review queue; topic freeze if reports exceed 3 per 1k | Review the queue | — |
| Mock builder | Weekly cron | Assembles tests from the exam blueprint (topic weights × difficulty) | None | Reuse last week's mock |
| Metrics digest | Weekly cron | Retention (D1/D7), MAU, report rate, conversion, revenue, API spend → Telegram | Read it (15 min) | — |
| Cost guard | Daily cron | Checks API and Supabase spend against budget | None | Above 150% of budget → batch jobs pause and you get an alert |
| Backups | Daily | Supabase dump → encrypted storage | None | — |

**Human-only (~20–30 min/day):** approving flagged items, confirming exam alerts, payment disputes, Dnyandeep and abhyasika relationships, and the weekly metrics review.

---

## 8. Distribution (no paid install ads in year 1)
1. **Telegram channel from week 6** (before the app): daily current-affairs quiz and PYQ of the day. Target 5k subscribers by launch.
2. **YouTube Shorts:** automated, faceless quiz videos.
3. **Abhyasikas:** 20 visits around Pune/your city, QR posters, a free B2B pilot for 5 centres.
4. **Educator rev-share:** 30% of pass revenue through promo codes.
5. **Referral:** each referred install gives both users a free mock.
6. **Dnyandeep parcel QR inserts**, if the deal goes through.
7. **ASO:** भरती सराव, पोलीस भरती सराव, तलाठी भरती प्रश्नपत्रिका.

---

## 9. Timeline (solo, ~16 weeks to paid)
| Week | Milestone |
|---|---|
| 0 | Name decided; domain, Play account, Supabase, repo scaffold |
| 1–2 | Schema, Police + Talathi topic graphs, anchor PYQ set, pipeline skeleton |
| 3–5 | Ingestion, generation, verification, calibration (**gate: verifier error under 2%**) |
| 4–8 | Flutter MVP: practice, PYQs, current-affairs quiz, report button, offline packs, AdMob |
| 6 | Telegram channel + review bot + daily current-affairs cron live |
| 8–10 | Closed test: 12+ testers for 14 days (paid service + real aspirants) |
| 10–11 | Production launch: Police + Talathi |
| 11–14 | Mocks, Exam Pass, other Group C exams |
| 14–16 | Book links, referrals, abhyasika pilots, Shorts automation |
| 24+ | Phase-2 library (Rajyaseva, RTO), funded from revenue |

---

## 10. Kill / continue criteria
- **Week 16:** fewer than 2k installs **and** Telegram under 2k → change distribution before adding any features.
- **Month 6:** D7 retention under 12% → product problem; stop expanding content.
- **Month 9:** revenue under 25% of costs and no B2B traction → pivot to B2B-only or wind down (max loss ~₹2.5–3L).
- **Any time:** report rate above 3 per 1k for 2 weeks → freeze generation and rely on PYQs only.

---

## 11. Risks and fallbacks
| Risk | Likelihood | Fallback |
|---|---|---|
| Wrong-answer incident goes viral | Medium | Auto-hide, public correction log, 7-day refund |
| Weak distribution | **High** | Telegram-first, abhyasikas, rev-share educators |
| Play Store rejection (policy/name) | Medium | Non-government brand; "not affiliated with the government" disclaimer; Play Billing |
| Ads underperform | High | Pass + B2B carry revenue |
| Dnyandeep deal fails | Medium | Amazon/Flipkart affiliate, second publisher |
| API price or model change | Low | Pipelines are model-agnostic; Haiku fallback; content is generated once and stored |
| PYQ copyright complaint | Low–Medium | Reword questions; cite official keys; answer takedowns within 24 h |
| Founder unavailable | Medium | Safe auto-publish rules; everything else pauses safely |
| Competitor copies you | Medium | Trust brand, B2B relationships and Marathi quality are the moat |

---

## Verification
- Pipeline: calibration shows verifier error under 2% on anchor PYQs before anything goes live; logged API spend per question is within ±30% of section 2.
- App: works offline on a 2 GB phone, renders Marathi correctly, AAB under 15 MB, crash-free rate above 99%.
- Business: weekly digest KPIs checked against the section 10 gates.

## 11b. Brand decision: **Bharari (भरारी)** — "soaring flight"
Tagline: **"उंच भरारी घ्या" ("Fly high")**. Domains: bharari.app, bharariapp.com, bharariapp.in (register all three; ~₹3k). File the trademark in classes 9 and 41. Package id: `app.bharari`.

## 11c. Play Store (ASO) + Google (SEO) plan — "appear when someone searches MPSC"
**Honest expectation:** "mpsc", "police bharti" and "talathi" are head terms held by Testbook, Adda247 and older apps with millions of installs. Play ranks by **keyword relevance × install velocity × retention/uninstall rate × rating**. Plan: top 10 on long-tail terms by month 2, top 10 on "police bharti test / talathi test" by month 4–6, and page 1 for "mpsc" only once installs and ratings are strong (month 6–12, not guaranteed).

**Play listing (en-IN default + mr-IN localized)**
- Title (30): `Bharari: MPSC, Police Bharti` (A/B test against `Bharari: Police Bharti & Talathi`).
- Short description (80): `MPSC, Police Bharti, Talathi mock tests & PYQ in Marathi. Free daily quiz.`
- Full description (4,000 chars): natural English + Marathi text mentioning mpsc, mpsc rajyaseva, police bharti 2026, talathi bharti, zp bharti, question paper, mock test, current affairs marathi, 3–5 times each, no stuffing.
- 8 screenshots with English captions and Marathi UI; a feature graphic; a 30-second promo video.
- Store listing experiments (free in the Play Console): test icon, title and screenshots every 2 weeks.
- **Custom store listings** per ad or referral link (MPSC-focused, Police-focused).

**Ranking signals we can drive**
- Install velocity: time launch and pushes with exam notifications; route Telegram, YouTube and abhyasika traffic straight to the Play link.
- Ratings: in-app review API prompt after a good result (score above 70%, or a 7-day streak), never after a failure. Target 4.5+.
- Retention and uninstalls: small APK, offline mode, no aggressive ads (Play uses these as quality signals).
- Reply to every review within 48 h (automated draft via Claude plus your one-tap approval in the Telegram bot).
- Android vitals: crash rate under 1%, ANR rate under 0.47% (Play demotes apps above these).

**Google web search (SEO), for "mpsc question paper", "police bharti test" etc.**
- A **bharari.app web mirror**: an auto-generated static site from the same question bank. One page per PYQ paper, topic and daily current-affairs quiz, in Marathi + English, with a Quiz schema and an "Open in app / Install" banner. This is fully automated from the same pipeline (Next.js/Astro static export, rebuilt daily by GitHub Actions, hosted free on Cloudflare Pages).
- Target long-tail pages: "police bharti question paper 2025 pdf", "talathi bharti question paper marathi", "mpsc current affairs today marathi".
- Google Search Console + sitemap. App Links so web visitors open in the app.
- YouTube Shorts titles and descriptions carry the same keywords and link to the Play listing.

**Tracking:** Play Console acquisition reports (search terms), a weekly keyword-rank check (a free tool or a manual script) and Search Console queries go into the weekly digest.

Added cost: ~₹0–500/month (Cloudflare Pages is free). Build time: +1 week in M6.

## 11d. PRODUCT SPEC — Bharari: the one-stop revision companion
**Positioning:** "No courses, no lectures, no selling. Just the best practice and revision for every Maharashtra exam, in your pocket, even on the bus." We win on **explanation quality, speed, offline use, Marathi-first, and motivation**. We don't compete with coaching; we are the daily companion coaching students also use.

### Product principles (these decide every feature)
1. **2-minute value.** Open the app → useful within 10 seconds, done in 2 minutes. Built for bus, train, queue and tea-break study.
2. **One thumb, offline, low data.** Everything works one-handed and without internet, on a 2 GB phone.
3. **Explanation over question.** Every item teaches something, even when you get it right.
4. **Exam-aware everywhere.** Pick your exam once and every screen filters to it (Police / Talathi / ZP / Rajyaseva / RTO …).
5. **Pump, don't guilt.** Celebrate effort. Never shame a streak break ("Comeback बोनस!" = "Comeback bonus!" rather than "you lost").
6. **Trust visible.** An "✓ Official answer key" badge on PYQs, a one-tap report button, a public corrections log.

### Information architecture — 5 bottom tabs
| Tab | Purpose |
|---|---|
| **आज (Today)** | Home feed for the day: daily target ring, Daily 10, current-affairs quiz, due flashcards, today's motivation, exam countdown |
| **सराव (Practice)** | MCQs: exam → subject → topic → difficulty; PYQ papers; mock tests; custom quiz |
| **उजळणी (Revise)** | Flashcards (spaced repetition), mind maps, one-page notes, formula & fact sheets, "mistake book" |
| **प्रगती (Progress)** | Strengths heatmap, accuracy by topic, streak calendar, predicted score, badges, leaderboard |
| **मी (Me)** | Exam & target date, language, downloads, settings, reports sent, share/referral |

### Content formats (all generated by the same pipeline from the same syllabus graph)
| Format | Detail | Phase |
|---|---|---|
| **MCQs** exam-wise / subject-wise / topic-wise / difficulty | 4 options, instant feedback mode or test mode | MVP |
| **PYQ papers** | Official papers with the official key, timed or untimed, "how you'd have ranked" | MVP |
| **Best-in-class explanation** (standard below) | On every MCQ | MVP |
| **Daily 10** | 10 questions/day per exam: 6 on weak topics, 3 high-weight, 1 current affairs. Different for each exam | MVP |
| **Daily current affairs** | 10–15 Maharashtra + national MCQs + 1-line facts, exam-tagged | MVP |
| **Flashcards (spaced repetition, SM-2/FSRS)** | Fact cards, one-liners, "who/what/when" cards, Marathi grammar rules, math formulas, synonyms/antonyms, idioms (म्हणी, वाक्प्रचार) | MVP |
| **Mistake book** | Every wrong answer becomes a flashcard automatically and comes back until mastered | MVP |
| **One-page topic notes** | 150–300 word crisp summary per topic + a "10 facts to remember" list | v1.1 |
| **Mind maps** | Per topic: tree view generated as structured JSON and rendered natively (zoom/pan, tap a node → related flashcards/MCQs). E.g. "Maharashtra rivers", "Constitution parts" | v1.1 |
| **Fact sheets / tables** | Lists toppers memorize: Maharashtra districts & HQs, dams, national parks, first-in-India, schemes, awards, important days | v1.1 |
| **Mock tests** | Full exam pattern, negative marking as per the exam, state-wide rank, section analysis | v1.1 |
| **Speed round** | 60-second rapid-fire (reasoning/math/GK) for commute bursts; beat your own best | v1.1 |
| **Audio revision** | TTS (Marathi voice) reading flashcards / current affairs: "listen while travelling", works with the screen off, offline pre-generated | v1.2 |
| **Math shortcuts** | Step-by-step tricks for arithmetic (percent, time-work, ratio) with worked examples | v1.2 |
| **Previous-cutoff & exam info** | Pattern, syllabus, past cutoffs, marks per section, key dates per exam | MVP (static) |
| **Exam alerts** | New notification / admit card / result / answer key alerts per selected exam | MVP |

### Explanation standard (our moat — every MCQ)
1. **Answer + why** (2–3 lines, simple Marathi).
2. **Why the other options are wrong** (1 line each).
3. **Memory hook** (mnemonic / story / association), where useful.
4. **Related fact** ("Also remember: …"), which becomes a flashcard.
5. **Source badge:** Official key / PYQ year, or verified reference.
6. For math/reasoning: **step-by-step solution + shortcut method**.
7. Language toggle per question (मराठी ⇄ English).
Validated by the verification pipeline; explanations are also checked in pass 2.

### Motivation & "pump-up" system (Bharari = soaring)
| Element | How it feels |
|---|---|
| **Daily target ring** | Pick 10 / 20 / 50 questions/day; the ring fills with a satisfying animation and haptic |
| **Streaks with "wings"** | The streak shows as a bird rising higher each day (3, 7, 21, 50, 100 days = new sky levels). Freeze tokens are earned, not bought. Streak break → "Comeback bonus" |
| **XP & levels** | Levels named as a journey: उमेदवार (candidate) → अभ्यासू (studious) → योद्धा (warrior) → विजेता (winner) → अधिकारी (officer) |
| **Daily motivation card** | Every morning on Today: a quote, a 60-second success story (real selected candidates, with consent, or historical Maharashtra heroes: Shivaji Maharaj's discipline, Savitribai Phule, Dr. Ambedkar's study hours), or a study tip. Shareable as an image to WhatsApp status (free marketing) |
| **Exam countdown** | "Police Bharti: 43 days left. 1,240 questions to your goal." Personal plan adjusts automatically |
| **Celebration moments** | Confetti on personal bests, "पहिला 100%!" ("First 100%!"), topic mastered, rank jump |
| **Leaderboards** | Weekly, per exam, per district ("Top in Satara this week"); friendly, resets weekly so anyone can win |
| **Study buddies** | Add friends via code, see each other's streaks, send a "चला अभ्यास करू!" ("Let's study!") nudge |
| **Selection wall** | Users who got selected post a note; others see "5,000+ Bharari users, 120 selections" |
| **Smart notifications** | Maximum 2/day, at user-chosen times. Motivating, never nagging: "तुमचा Daily 10 तयार आहे 🔥" ("Your Daily 10 is ready 🔥") |
| **Weekly report card** | Sunday: shareable card with questions done, accuracy, best topic, streak |

### Built for travelling (commute mode)
- **Offline packs** per exam (download on WiFi, auto-update deltas).
- **Swipe cards UI:** swipe right = know, left = review again. One-handed.
- **Speed round and audio revision** for standing on a crowded bus/train.
- **Resume anywhere:** a test killed mid-way resumes exactly where it stopped.
- **Data saver:** no images unless needed; everything text + vector.
- **Large-font mode + dark mode** for night travel.

### Smart features (AI-assisted, cost-controlled)
| Feature | Phase |
|---|---|
| **Weak-topic engine:** per-topic accuracy + forgetting curve drive Daily 10 and flashcard queue | MVP (on-device rules, no API cost) |
| **Predicted score / readiness %** per exam | v1.1 |
| **Personal study plan** from target date + current level (auto-rebalanced weekly) | v1.1 |
| **"Explain differently"** button: an alternative simpler explanation. Pre-generated for the top 20% most-missed questions, so zero live API cost | v1.2 |
| **Doubt → "Ask Bharari"** live AI chat | ❌ Not in year 1 (cost, accuracy risk, moderation) |

### UI / design system
- **Brand look:** sky/sunrise palette (deep blue + saffron-orange accent), a bird/wings motif, rounded cards, bold Marathi headlines (Mukta or Noto Sans Devanagari), Material 3.
- **Micro-interactions:** correct = green pulse + light haptic; wrong = gentle shake + explanation slides up; ring fill; level-up animation (Lottie, small files).
- **Speed:** cold start under 2 s on a 2 GB phone; every screen works offline; no spinner longer than 300 ms (skeletons).
- **Accessibility:** large text, high contrast, colour-blind-safe correct/wrong (icon + colour).
- **Onboarding in 3 taps:** language → exam(s) → daily goal. Instant first Daily 10, no login.
- Design first in **Figma** (or directly with Flutter prototypes). Test with 5 real aspirants before coding the full app.

### Deliberately NOT building (keeps focus)
Video lectures/courses, live classes, a doubt-chat community (moderation load), PDF downloads of copyrighted books, paid coaching tie-ups that sell courses.

### Feature phasing summary
- **MVP (launch):** 5 tabs, MCQs (exam/subject/topic/difficulty), PYQs, Daily 10, daily current affairs, flashcards + mistake book, explanations, streak/ring/XP, daily motivation card, exam countdown, alerts, offline packs, report button, rewarded ads.
- **v1.1 (+6 weeks):** mock tests + rank, one-page notes, mind maps, fact sheets, speed round, leaderboards, weekly report card, readiness %, study plan.
- **v1.2 (+12 weeks):** audio revision, math shortcuts, study buddies, selection wall, "explain differently", Exam Pass.

### Content cost impact (added to section 2)
Flashcards, notes, mind maps and fact sheets are produced per topic, not per question. About 1,500 topics × (notes + mind map JSON + 30 flashcards) ≈ 1,500 × ~6k output tokens with Sonnet 5 batch ≈ **$45 (~₹4k)**, plus verification ≈ **₹8–10k total**. Motivation content (365 quotes/stories/tips): ~₹500. Audio TTS pre-generation (Google/Azure Marathi TTS): ~₹2–4k one-time.

## 12. Freemium model (launch configuration)
| Free forever | Unlocked by a rewarded ad (free) | Exam Pass (month 3+, one-time payment) |
|---|---|---|
| Topic practice, all PYQs, daily current-affairs quiz, flashcards, streaks | 1 extra full mock per ad, detailed solutions batch, "weak topics" report | Unlimited mocks, state rank, analytics, ad-free, offline full pack |

Rules: no interstitial ads during tests; at most 1 app-open ad per day; ads never block core practice. The paywall ships **after** retention is proven (D7 ≥ 15%). Until then the app is ads-only.

---

## 13. Implementation project plan

### Repo structure (monorepo)
```
/app                Flutter Android app
  lib/core          theme, i18n (mr/en), routing, DI
  lib/data          drift DB, Supabase client, sync, pack downloader
  lib/features      onboarding, exam_picker, practice, pyq, ca_quiz, mock, results, report, streaks, ads, pass
/pipeline           Python 3.12, uv, anthropic SDK
  ingest/           pdf+OCR → structured PYQs
  generate/         batch generation
  verify/           pass1, pass2, tiebreak, calibrate
  ca_daily/         RSS → MCQs
  review_bot/       Telegram approve/reject
  publish/          app pack builder, Telegram, YouTube Shorts (FFmpeg)
  watchers/         exam-notice diff, cost guard, metrics digest
  common/           db, prompts/, schemas (pydantic), costs
/supabase           migrations, RLS policies, edge functions (report, sync, pass-verify)
/.github/workflows  ci.yml, ca_daily.yml, watchers.yml, calibrate.yml, digest.yml, backup.yml
/docs               runbooks: incident, content-correction, release
```

### Milestones, epics and tasks (solo, ~20–25 h/week)
**M0 — Foundations (week 0–1)**
- Brand decision, domain, Play developer account, Supabase project, GitHub repo, Anthropic API key with a monthly spend limit set in the console.
- CI: `flutter analyze` + tests, `ruff` + `pytest`, migration lint.
- Deliverable: empty app builds and signs an AAB; pipeline hello-world calls the API.

**M1 — Data spine (weeks 1–2)**
- Migrations for all section 6 tables, row-level security policies, seed of states/exams.
- Topic-graph extractor: syllabus PDF → Claude → JSON → you approve → insert.
- Police Bharti + Talathi graphs approved.
- Deliverable: queryable syllabus graph.

**M2 — Content engine (weeks 2–5)** ⟵ critical path
- Ingest: OCR (Tesseract-mar, Google Vision as fallback) → Haiku structuring → dedupe (embedding/trigram) → reconcile against the official answer keys.
- Generate: Batch API jobs with cached per-topic prompts; structured outputs (pydantic schema).
- Verify: pass 1 (blind solve), pass 2 (critique), tie-breaker, confidence score, status assignment.
- Calibrate: run on the anchor PYQs and write a report. **Gate: error under 2%.**
- Cost ledger: log token usage per job to a `costs` table.
- Deliverable: 15k live Group C questions and a calibration report.

**M2.5 — Design sprint (weeks 2–4, in parallel with M2)**
- Brand kit (logo, palette, type), Figma screens for the 5 tabs, question player, flashcard swipe, results and celebration.
- Clickable prototype tested with 5 aspirants (from Telegram/abhyasika). Iterate once.
- Deliverable: approved UI kit + Flutter theme tokens.

**M3 — App MVP (weeks 4–9), scope = the MVP list in section 11d**
- Onboarding (language, exam, target date) with no login required.
- Pack downloader → offline drift DB; batched attempt sync.
- Practice (topic/difficulty), PYQ paper mode with a timer, results with explanations.
- Report button → edge function → auto-hide logic.
- Streaks, basic stats, FCM topic subscription per exam.
- AdMob rewarded unlock for extra mocks.
- Marathi-first i18n, Noto Devanagari font, low-data mode.
- Deliverable: internal-test AAB on the 2 GB phone.

**M4 — Automation ops (weeks 5–7, in parallel with M3)**
- Telegram review bot (inline buttons → status update).
- Daily current-affairs workflow + auto-publish fallback rule.
- Publishers: app, Telegram channel. Exam-notice watcher.
- Cost guard, metrics digest, daily backup.
- Deliverable: Telegram channel live with the daily quiz (audience building starts).

**M5 — Closed test and launch (weeks 8–11)**
- Privacy policy, terms, data-safety form, "not a government app" disclaimer, content rating.
- Closed test with 12+ testers for 14 days: paid service plus aspirants recruited from Telegram. Feedback form in the app.
- Fix pass. Store listing in Marathi with screenshots and the keyword title.
- Production rollout: 20% → 100%.
- Deliverable: live on Play.

**M6 — Growth features (weeks 11–16)**
- Weekly auto-built mocks + state-wide rank.
- Flashcards, weak-topic revision.
- Referral links (Firebase Dynamic Links replacement: App Links + referral code).
- Book links (Dnyandeep / Amazon affiliate).
- YouTube Shorts generator.
- Remaining Group C exams.

**M7 — Monetization v2 (month 4–6, gated on D7 ≥ 15%)**
- Exam Pass via Play Billing one-time products; server-side purchase verification.
- B2B abhyasika: class code, simple owner dashboard (web), monthly invoice.
- Phase-2 library: Rajyaseva prelims and RTO.

### Definition of done for each release
Analyzer and tests clean, crash-free rate ≥ 99% in internal test, AAB under 15 MB, works offline, and every new question batch carries a calibration pass.

### Weekly operating rhythm (after launch)
- Daily, ~20 min: Telegram review queue.
- Monday: metrics digest and plan the week.
- Wednesday: abhyasika or educator outreach, 2 hours.
- Friday: release (if any) and content-correction log.

---

## First build step (after approval)
Scaffold the repo: `/app` (Flutter), `/pipeline` (Python: ingest, generate, verify, calibrate, ca_daily, review_bot, publisher, watchers), `/supabase/migrations`, `.github/workflows` (cron jobs). Start with the schema and the Police Bharti topic graph.

Sources: mahapariksha.gov.in (government portal); the "Mahapariksha – Free Test Series" app listing on APKPure; RDAP domain lookups; Anthropic API pricing.
