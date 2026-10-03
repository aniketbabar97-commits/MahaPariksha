# RailPariksha launch checklist

Live, checkable version: https://claude.ai/artifact/Y2Xo461VWazb8ie762PYdi

## Targets

- **Tester submission:** Friday, 2 Oct 2026 — get 12 testers into closed testing (starts the mandatory 14-day clock)
- **Public go-live:** end of October 2026
- **Growth target:** 10,00,000 (10 lakh) users within 6 months of launch

## Your checklist (account/identity — only the account owner can do these)

- [ ] Create Google Play Console account ($25 one-time fee at play.google.com/console). Google may hold new accounts 1-2 days for identity verification — start this first.
- [ ] Create the app in Console: name "RailPariksha", package `app.railpariksha`, default language en-IN, free app.
- [ ] Generate the signing keystore (`keytool -genkey ... railpariksha-upload.jks`) — keep this file safe forever; losing it means you can never update the app again.
- [ ] Add 4 GitHub repo secrets: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- [ ] Host the privacy policy + T&C publicly — paste `docs/store/PRIVACY_POLICY_for_google_doc.md` and `TERMS_for_google_doc.md` into public Google Docs, grab the share links.
- [ ] Recruit 12 testers — RRB/RPF Telegram or Facebook aspirant groups (free, authentic feedback) or a paid crowd-testing gig as backup. Get their Gmail addresses.
- [ ] Manually upload the first signed AAB — Google requires the very first upload through the Console UI. Download the `.aab` from the GitHub Actions run once a release is tagged.
- [ ] Fill Play Console listing forms: privacy policy URL, Data safety (no data collected), Content rating (Everyone), Ads = No, Government-affiliation = not affiliated.
- [ ] Get all 12 testers to install + open the app once — this starts the 14-continuous-day closed-testing clock.
- [ ] Share real PYQ (previous-year-question) papers per exam, so we can mix verified real exam questions into the bank and build dedicated PYQ mock tests — one or more years each for: RRB NTPC (UG/Graduate), RRB Group D, RRB ALP, RRB Technician, RRB JE (Mechanical/Civil/Electrical), RRB Paramedical, RPF Constable, RPF SI, DFCCIL Executive/Jr. Executive.

## My checklist (repo side)

- [x] Push held commits + update the PR — Oct 1 quota reset, pushing continuously since.
- [ ] Tag a `railpariksha-vX.Y.Z` release once the 4 keystore secrets are in place — produces the signed `.aab`.
- [x] Final pre-tag smoke pass — `pipeline/validate.py` and `build_bundle.py` both clean (43 files, 27,377 items, 0 errors); `flutter analyze`/`test`/release-build/e2e all green in CI as of PR #4.
- [x] Generate remaining questions to 25,000 — done: 25,144 total, every subject's every topic hit its per-topic target.
- [x] Generate notes/mind-maps for every topic missing one — the real gap was down to 4 topics (science x3, current_affairs/railway_current_affairs), not 27; all 4 drafted and fact-checked (fixed a stale "100% electrification by Dec 2023" claim to the verified ~99.6%-by-2025 figure).
- [x] Generate flashcards for subjects with zero — only `current_affairs` actually had none (the other 4 listed here already had cards from earlier sessions); 54 new cards added across its 9 topics.
- [x] Finish tips & tricks backfill on existing notes — 85/88 notes already have tips; the 3 remaining are addressed by the note-generation above.
- [x] Fact-check pass on the new current-affairs content — caught and fixed 7 stale "current office-holder" facts (RBI Governor, CEC, NITI Aayog CEO, CAG, newest BRICS member, a malformed electrification Q/A pair) via live web search against Oct 2026 sources.
- [x] Ship daily current-affairs freshness automation — already live: `.github/workflows/railpariksha_current_affairs.yml` drafts + cross-checks new CA questions every morning and opens a PR for review.
- [ ] Deploy the SEO/AEO site once a domain exists — `pipeline/build_site.py` already produces pages with structured data; just needs hosting + the domain from your checklist above.
- [ ] Build a PYQ section — blocked on you sharing real PYQ papers (see your checklist above); once supplied, add a "PYQ" content type alongside notes/flashcards/quiz and a PYQ mock-test mode mixing real PYQs with our own bank questions.

See `docs/LAUNCH.md` for the fuller step-by-step detail behind each account-side item.
