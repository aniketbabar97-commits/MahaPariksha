# AdMob integration

AdMob App ID: `ca-app-pub-9100209280220037~3428622385`

## What's live

Interstitials are paced by `AdPacing` (`lib/core/ads.dart`); everything below is skipped for
ad-free purchasers (`Progress.removedAds`).

- **Banner** — anchored adaptive banner (full screen width) at the bottom of Progress, Practice,
  the PYQ lists and the results screen. Never on a quiz-taking screen (mock, practice, Beast Mode,
  flashcards) where it would interrupt focus. Shown only once loaded, labelled "Advertisement" and
  spaced away from buttons.
- **Native** — a small native ad card in the PYQ lists (after every 8th exam set, and after the
  6th paper inside a set).
- **Interstitial** — on the results screen after a completed quiz or paper in any mode except
  the onboarding placement quiz and the 60-second speed round. The first 2 quizzes a user ever
  finishes are ad-free, then every 10th completion shows one, never closer than 3 minutes to the
  previous. It is skipped on a turn when the in-app review sheet is due, so two interruptions never
  stack. It is preloaded when a quiz that is due for an ad starts (`quiz_screen.dart`); if it isn't
  ready in time it is silently skipped rather than delaying the results screen.
- **Rewarded — PYQ.** Practice sets: one ad opens the PYQ section's practice sets for 30 minutes.
  Full papers: one ad per paper, valid for 2 hours (a paper is a 90-minute sitting). If no ad can
  load (two failed loads in a row) the PYQ opens for 20 minutes on us, at most twice per app
  session; nobody earns from an ad that can't load. See `PyqAccess` in `pyq_screen.dart`.
- **Rewarded — streak freeze.** Opt-in card on the Progress screen, one freeze token per watch
  (capped at 2, see `Progress.freezeTokens`).

## Analytics

`Analytics.log` (`lib/core/analytics.dart`) sends anonymous Firebase Analytics events and does
nothing when Firebase isn't configured. Events: `pyq_open`, `pyq_set_open`, `pyq_gate_shown`,
`pyq_unlocked` (via ad or courtesy), `pyq_ad_not_ready`, `pyq_paper_start`, `quiz_start`,
`quiz_complete`, `interstitial_shown`. No names, emails or question text are ever logged.

## Reserved, not yet wired anywhere

Ad unit IDs exist in `lib/core/ads_config.dart` for **Rewarded Interstitial** and **App Open**,
but nothing shows them. App Open has to be used sparingly (not on every cold start) and needs its
own design pass.

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

## Play Console declarations needed

- **Ads:** "Yes, my app contains ads".
- **Data safety:** declare *Device or other IDs* (advertising ID, AdMob) and *App activity / App
  interactions* (Firebase Analytics, collected, not linked to identity). The privacy policy
  (`PRIVACY_POLICY_for_google_doc.md`) already covers both; publish the updated policy before this
  release, since analytics is new.
