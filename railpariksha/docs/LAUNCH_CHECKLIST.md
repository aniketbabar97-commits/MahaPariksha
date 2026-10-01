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
- [ ] Final pre-tag smoke pass — validate content bank + compile-check before tagging, so the first upload isn't wasted on an avoidable bug.
- [x] Generate remaining questions to 25,000 — done: 25,078 total, every subject's every topic hit its per-topic target (311/topic, 15/topic for current_affairs).
- [ ] Generate notes/mind-maps for the 27 topics missing them — all 18 JE topics plus scattered GK/Computer/English ones currently have quiz questions but no notes page.
- [ ] Generate flashcards for the 5 subjects with zero — current_affairs, english, je_mechanical, je_civil, je_electrical; the Revise tab shows nothing for these today.
- [ ] Finish tips & tricks backfill on existing notes — adds exam-hall mnemonics/shortcuts to notes that predate the `tips_hi`/`tips_en` field.
- [ ] Resume + grow verification coverage — paused for now to prioritize closing the content gap; resume once generation nears 25,000.
- [ ] Ship daily current-affairs freshness automation — so that one date-sensitive subject doesn't go stale after launch.
- [ ] Deploy the SEO/AEO site once a domain exists — `pipeline/build_site.py` already produces 111 pages with structured data; just needs hosting.
- [ ] Build a PYQ section — tag real previous-year questions by exam + year once supplied, add a "PYQ" content type alongside notes/flashcards/quiz, and a PYQ mock-test mode that mixes real PYQs with our own bank questions (not pure-PYQ-only).

See `docs/LAUNCH.md` for the fuller step-by-step detail behind each account-side item.
