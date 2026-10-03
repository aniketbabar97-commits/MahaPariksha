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
- [x] Create a free Firebase project + Firestore database (Production-mode rules published) for the leaderboard backend — `google-services.json` is committed, Firestore rules are live.
- [x] (this session) Hired Testers Community (Starter plan, 1 credit) to supply 15 testers within ~6 hours once the closed testing track + opt-in URL exist — covers the 12-tester minimum.
- [ ] Manually upload the first signed AAB — Google requires the very first upload through the Console UI. **Download link coming once today's release build finishes** (see "Today's build" note below) — do NOT use the old `railpariksha-v1.0.2` AAB, it predates today's bug fixes.
- [~] Play Console listing — mostly done this session: app content declarations (Ads = Yes/AdMob, Advertising ID = Yes, Data safety, Content rating, Target audience, Government apps, Financial features, Health apps), store listing (name, short/full description, icon, feature graphic, 5 screenshots) all filled in. Still to confirm: category + contact email/website if not already set.
- [ ] Set up the closed testing track + add tester emails (from Testers Community once they're assigned); send them the opt-in URL — this also unblocks submitting to Testers Community.
- [ ] Get all 12+ testers to install + open the app once — starts the 14-continuous-day closed-testing clock.
- [ ] Share real PYQ (previous-year-question) papers per exam — one or more years each for: RRB NTPC (UG/Graduate), RRB Group D, RRB ALP, RRB Technician, RRB JE (Mechanical/Civil/Electrical), RRB Paramedical, RPF Constable, RPF SI, DFCCIL Executive/Jr. Executive.
- [ ] Buy + point a domain (e.g. on Hostinger) so the SEO/AEO site and the content pack have somewhere to live.

## My checklist (repo side)

- [x] v1.0.0 shipped, then v1.0.1 to fix a crash-on-launch bug (R8 stripped a class WorkManager needed reflectively) found via real device testing — both tagged releases exist.
- [x] Emulator-based golden-path e2e test added as a release gate, verified green against the actual signed release build.
- [x] Generate remaining questions to 25,000+, every topic's notes/mind-maps, flashcards for every subject, tips & tricks backfill — all done across earlier sessions.
- [x] Ship daily current-affairs freshness automation — `.github/workflows/railpariksha_current_affairs.yml` drafts + cross-checks new CA questions every morning and opens a PR for review.
- [x] Closed the last real content gaps the above missed: 4 topic notes and `current_affairs`'s flashcards (the one subject that genuinely had none) — see PR #5.
- [x] Fact-checked every new current-affairs claim via live web search against today's date: fixed 7 stale "current office-holder" facts (RBI Governor, CEC, NITI Aayog CEO, CAG, newest BRICS member) and a malformed Q/A pair — see PR #5.
- [x] Weak Spots Drill, Revision Plan, and a mock-score percentile *estimate* — see PR #4. The percentile is a local statistical estimate (no backend, clearly labeled), separate from the real leaderboard below.
- [x] **Built the real leaderboard** — anonymous per-exam, weekly-reset, Firestore-backed, wired to the now-live Firebase project. Device-ID + chosen-name identity, no real accounts — see PR #5.
- [x] **AdMob ads shipped live** (banner on Progress, interstitial after mock tests, rewarded for streak-freeze) — privacy policy and Play Console declarations updated to match.
- [~] Full bank-wide fact-check pass across the *entire* existing question bank — in progress, resumable (checkpointed per subject). As of this session: maths/computer/current_affairs/science essentially 100% checked, gk ~96%, reasoning ~72%, english/railway_gk/je_civil/je_electrical/je_mechanical were only ~3-5% checked — 3 workers now actively finishing those, auto-resume on restart via the session-start hook (fixed this session, see below). ~360+ flags accumulated; a large backlog (mostly `reasoning.json`, 310 flags) still needs personal triage before any fix is applied — flags are never auto-applied.
- [x] **Found and fixed a real shipped UI bug** via the user's own device testing: a global `FilledButton`/`OutlinedButton` theme default (`Size.fromHeight(52)`, infinite minimum width) caused catastrophic character-by-character text wrapping whenever one of those buttons sat inline next to other content (not full-width). Root-caused and fixed 8 live instances across the app (Premium card, streak-freeze card, Practice/Progress headers, 4 confirmation dialogs).
- [x] **Full line-by-line correctness audit of all 21 app screens** — found and fixed one more divide-by-zero landmine (`exam_strategy_screen.dart`, guarded against a future `paperQuestions: 0`); confirmed everything else (null-safety, `.first`/`.last` usage, division) was already safely guarded.
- [x] **Motion/polish pass**: count-up numbers (score, XP, daily goal, days-to-exam), animated progress-bar fills, and press-scale tap feedback added to Today/Results/Progress/Quiz/Me, then extended consistently to every tappable card across all 21 screens (not just the 5 highest-traffic ones); skeleton loading states replace bare spinners (leaderboard).
- [x] **Fixed a stale session-start hook**: it was relaunching a retired, non-resumable fact-check script instead of the actual resumable one in use since earlier this session — meant every container restart silently did nothing useful. Fixed and verified working.
- [x] **Release pipeline now works without a tag push**: this session's GitHub write access is scoped to its working branch only (can't push a `railpariksha-v*` tag), so added an unconditional `actions/upload-artifact` step to the release workflow — a `workflow_dispatch` run now produces a downloadable signed AAB/APK even without a tag, verified through the same e2e gate as a tagged release.
- [ ] Deploy the SEO/AEO site once a domain exists — `pipeline/build_site.py` already produces the pages; just needs hosting + your domain.
- [ ] Build a PYQ section + PYQ mock-test mode — blocked on you sharing real PYQ papers; once supplied, add a "PYQ" content type and a mock mode mixing real PYQs with our own bank questions.

## Today's build

A release build triggered manually (no tag push needed — see fix above) is running/has run against everything from this session: the button-squeeze fix, the 21-screen audit, the full motion pass, the live leaderboard, and live ads. Once it finishes, the signed AAB and APK get sent to you directly — that's the one to upload to Play Console, not the older `railpariksha-v1.0.2` release.

See `docs/LAUNCH.md` for the fuller step-by-step detail behind each account-side item.
