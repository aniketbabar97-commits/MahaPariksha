# AdMob integration

AdMob App ID: `ca-app-pub-9100209280220037~3428622385`

## What's live in v1

- **Banner** — bottom of the Progress screen only. Never shown on a
  quiz-taking screen (mock, practice, Beast Mode, flashcards) where it would
  interrupt focus.
- **Interstitial** — shown once, on the Results screen, only after a
  **mock test** (`QuizMode.mock`) — not after Daily 10, practice, or Beast
  Mode, to keep frequency tasteful for a serious daily-use study tool.
  Preloaded when the mock starts (`quiz_screen.dart` initState) so it's
  usually ready by the time results appear; if it isn't ready in time, it's
  silently skipped rather than delaying the results screen.

## Reserved, not yet wired anywhere

Ad unit IDs exist in `lib/core/ads_config.dart` for **Rewarded**,
**Rewarded Interstitial**, **Native**, and **App Open**, but nothing in the
app shows them yet. Candidate future uses:
- Rewarded: "watch an ad for one extra Beast Mode retry" or similar --
  ties into the existing Beast Mode replay flow.
- App Open: has to be used sparingly (not on every cold start) to avoid
  feeling intrusive -- needs its own design pass before wiring up.
- Native: would need an in-feed placement (e.g. between practice topic
  tiles) with a custom native ad layout -- more design/implementation work
  than banner/interstitial.

## Test vs real ads

Every build defaults to Google's official test ad unit IDs
(`lib/core/ads_config.dart`, `useTestAds` = `bool.fromEnvironment`,
default `true`). Only `railpariksha_release.yml` (the actual Play Store
release build) passes `--dart-define=USE_TEST_ADS=false` to switch to the
real ad units above. This means:
- The CI-built test APK (`railpariksha_ci.yml`) and any local dev build
  always show test ads -- safe to tap around on without risking an AdMob
  policy violation for invalid traffic on the real, brand-new ad units.
- Only a real tagged release (`railpariksha-v*`) ever serves real ads.

## Play Console declarations still needed

Once this ships, the Play Console **Ads** declaration must say "Yes, my
app contains ads," and the Data safety section needs to disclose that
AdMob collects an advertising identifier for ad personalization. The
privacy policy (`docs/store/PRIVACY_POLICY_for_google_doc.md`) already has
placeholder language for this -- update the "Ads (when enabled)" section
to remove the "if and when" hedging once this is live.
