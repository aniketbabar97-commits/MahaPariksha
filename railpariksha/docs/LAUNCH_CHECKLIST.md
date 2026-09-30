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

## My checklist (repo side)

- [ ] Push the 46 held commits + update the PR — blocked until the Oct 1 Actions-minutes quota resets.
- [ ] Tag a `railpariksha-vX.Y.Z` release once the 4 keystore secrets are in place — produces the signed `.aab`.
- [ ] Final pre-tag smoke pass — validate content bank + compile-check before tagging, so the first upload isn't wasted on an avoidable bug.
- [ ] Keep content generation running — close the reasoning/maths/JE gaps toward target.
- [ ] Push verification coverage further — grow past the current thin sample so more of the 16k+ bank is actually fact-checked before production launch.
- [ ] Ship daily current-affairs freshness automation — so that one date-sensitive subject doesn't go stale after launch.
- [ ] Deploy the SEO/AEO site once a domain exists — `pipeline/build_site.py` already produces 111 pages with structured data; just needs hosting.

See `docs/LAUNCH.md` for the fuller step-by-step detail behind each account-side item.
