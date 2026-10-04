# AdMob integration

AdMob App ID: `ca-app-pub-9100209280220037~3428622385`

## What's live

Interstitials are paced by `AdPacing` (`lib/core/ads.dart`); everything below is skipped for
ad-free purchasers (`Progress.removedAds`).

- **Banner** — anchored adaptive banner (full screen width), via `AdSlot` at the end of: Today,
  Practice, subject screens, Revise, Progress, Me, topic notes, GK Booster, revision plan, exam
  strategy, cheat sheets, current-affairs digest, search results, the PYQ lists and the results
  screen. **Never** on a screen where a question is open (mock, practice, Beast Mode, flashcards,
  Reel cards): an ad beside answer buttons causes accidental taps, which AdMob treats as invalid
  traffic and can suspend the account for. Shown only once loaded, labelled "Advertisement" and
  spaced away from buttons.
- **Native** — small native cards in feeds and lists: the PYQ lists (every 8th exam set, and after
  the 6th paper in a set), the current-affairs digest (every 4th item), search results (every 10th),
  and the results answer review (every 8th question). In Reel Mode, a full-page labelled "Sponsored"
  card every 8 cards, inserted only once an ad has actually loaded.
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
- **Rewarded — double XP.** Opt-in card on practice-style results: watch one ad, get that quiz's
  XP again (once per result screen). Hidden when ads can't load.
- **Rewarded — streak freeze.** Opt-in card on the Progress screen, one freeze token per watch
  (capped at 2, see `Progress.freezeTokens`).

## Analytics

`Analytics.log` (`lib/core/analytics.dart`) sends anonymous Firebase Analytics events and does
nothing when Firebase isn't configured. Events: `pyq_open`, `pyq_set_open`, `pyq_gate_shown`,
`pyq_unlocked` (via ad or courtesy), `pyq_ad_not_ready`, `pyq_paper_start`, `quiz_start`,
`quiz_complete`, `interstitial_shown`. No names, emails or question text are ever logged.

- **App open** — only when a student *returns* to the app: never on a cold start, never while a
  question is open (`AdGuard`), only after 30+ minutes in the background, at most once per 4 hours,
  and not until 3 quizzes are finished. Switch off with `AppOpenAdManager.enabled = false`.

## Reserved, not yet wired anywhere

An ad unit ID exists in `lib/core/ads_config.dart` for **Rewarded Interstitial**, but nothing shows it.

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
