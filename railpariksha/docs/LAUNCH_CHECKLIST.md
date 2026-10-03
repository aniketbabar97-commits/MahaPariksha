# RailPariksha launch checklist

Live, checkable version: https://claude.ai/artifact/Y2Xo461VWazb8ie762PYdi — that artifact is the
source of truth for day-to-day progress; this file is a periodic snapshot of it; the two can drift
out of sync between syncs, which is what happened before this update.

## Targets

- **Tester submission:** 12 testers into closed testing (starts the mandatory 14-day clock)
- **Public go-live:** end of October 2026
- **Growth target:** 10,00,000 (10 lakh) users within 6 months of launch

## Your checklist (account/identity — only the account owner can do these)

- [x] Create Google Play Console account
- [x] Create the app in Console: name "RailPariksha", package `app.railpariksha`, default language en-IN, free app.
- [x] Generate the signing keystore — keep this file safe forever; losing it means you can never update the app again.
- [x] Add 4 GitHub repo secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- [x] Host the privacy policy + T&C publicly.
- [ ] Recruit 12 testers — RRB/RPF Telegram or Facebook aspirant groups, or a paid crowd-testing gig as backup. Get their Gmail addresses.
- [ ] Manually upload the first signed AAB — Google requires the very first upload through the Console UI. Download the `.aab` from the `railpariksha-v1.0.1` release.
- [ ] Fill Play Console listing forms: privacy policy URL, Data safety (no data collected), Content rating (Everyone), Ads = No, Government-affiliation = not affiliated.
- [ ] Set up the closed testing track + add the 12 tester emails; send them the opt-in URL.
- [ ] Get all 12 testers to install + open the app once — starts the 14-continuous-day closed-testing clock.
- [ ] Share real PYQ (previous-year-question) papers per exam — one or more years each for: RRB NTPC (UG/Graduate), RRB Group D, RRB ALP, RRB Technician, RRB JE (Mechanical/Civil/Electrical), RRB Paramedical, RPF Constable, RPF SI, DFCCIL Executive/Jr. Executive.
- [ ] Buy + point a domain (e.g. on Hostinger) so the SEO/AEO site and the content pack have somewhere to live.
- [ ] Create a free Firebase project (`google-services.json`) for the planned leaderboard backend.

## My checklist (repo side)

- [x] v1.0.0 shipped, then v1.0.1 to fix a crash-on-launch bug (R8 stripped a class WorkManager needed reflectively) found via real device testing — both tagged releases exist.
- [x] Emulator-based golden-path e2e test added as a release gate, verified green against the actual signed release build.
- [x] Generate remaining questions to 25,000+, every topic's notes/mind-maps, flashcards for every subject, tips & tricks backfill — all done across earlier sessions.
- [x] Ship daily current-affairs freshness automation — `.github/workflows/railpariksha_current_affairs.yml` drafts + cross-checks new CA questions every morning and opens a PR for review.
- [x] (this session) Closed the last real content gaps the above missed: 4 topic notes and `current_affairs`'s flashcards (the one subject that genuinely had none) — see PR #5.
- [x] (this session) Fact-checked every new current-affairs claim via live web search against today's date: fixed 7 stale "current office-holder" facts (RBI Governor, CEC, NITI Aayog CEO, CAG, newest BRICS member) and a malformed Q/A pair — see PR #5.
- [ ] Run a full fact-check pass across the *entire* existing question bank (not just this session's new content) — 3 Groq-model workers blind-solving stored questions, flagging disagreements for human review; in progress, resumable across restarts.
- [x] (this session) Weak Spots Drill, Revision Plan, and a mock-score percentile *estimate* — see PR #4. The percentile is a local statistical estimate (no backend, clearly labeled), not the real leaderboard below.
- [ ] Build the real leaderboard / social-competitive layer — anonymous per-exam leaderboards, weekly-reset top scores, your rank against them. Client-side schema/UI can proceed now; wiring to Firestore happens once your Firebase project's `google-services.json` is in hand.
- [ ] Deploy the SEO/AEO site once a domain exists — `pipeline/build_site.py` already produces the pages; just needs hosting + your domain.
- [ ] Build a PYQ section + PYQ mock-test mode — blocked on you sharing real PYQ papers; once supplied, add a "PYQ" content type and a mock mode mixing real PYQs with our own bank questions.

See `docs/LAUNCH.md` for the fuller step-by-step detail behind each account-side item.
