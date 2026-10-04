# Owner to-do (things only you can do)

Kept in the repo so it travels with the project. Tick items off as you go.

## Before the next Play Store release
- [ ] **Publish the updated privacy policy.** Source: `docs/store/PRIVACY_POLICY_for_google_doc.md`
      (new "Usage analytics" paragraph in English and Hindi). It must be live before the release
      that ships analytics.
- [ ] **Play Console → App content → Data safety.** Declare:
  - *Device or other IDs* (advertising ID, used by AdMob)
  - *App activity → App interactions* (Firebase Analytics; anonymous, not linked to identity)
  - And the **Ads** declaration: "Yes, my app contains ads".
- [ ] **Resubmit the store listing** with the new description (disclaimer at the top, Official
      Sources section) to clear the Misleading Claims rejection. Text: `docs/store/play_desc_en.txt`
      and `docs/store/play_desc_hi.txt`.

## Daily current-affairs job
- [x] **Add the API key as a GitHub secret** (done: `GEMINI_API_KEY` added): repo → Settings → Secrets and variables → Actions →
      *New repository secret* → `GEMINI_API_KEY` (optionally also `GROK_API_KEY`,
      `ANTHROPIC_API_KEY` for the extra Claude check). Then Actions → "RailPariksha daily current
      affairs" → *Run workflow* to test it. Until a key exists the job skips quietly (no failure
      emails). Two news feeds (PIB, Indian Express) return 403 to GitHub's servers; the job runs
      on the other feeds.

## After launch (needs about 2 weeks of Firebase Analytics data)
- [ ] **Watch day-1 and day-7 retention.** If either falls compared with the first week, cut ads in
      this order: 1) native ads, 2) the results-screen banner, 3) only then relax the interstitial
      beyond every 10th quiz (`AdPacing.every` in `app/lib/core/ads.dart`). Keep the per-paper PYQ
      rewarded ad; it is opt-in and the main earner.
- [ ] **Replace the model's guesses with real numbers.** Compare real eCPMs and ads per user from
      AdMob against `docs/UX_ADS_GROWTH_AUDIT.md` section 4 and re-run the 10 lakh / 180-day
      estimate.
