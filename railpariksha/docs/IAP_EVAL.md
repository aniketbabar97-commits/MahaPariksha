# In-app purchase: remove ads / unlock full offline mode

**Decision: GO. Implemented in this change -- but still needs a real
`flutter build apk --release` on a device/CI to confirm, and Play Console
product setup is a manual step for the account owner (below).**

## What was asked

A market-survey finding says competitors' subscription-only model leaves
price-sensitive users unconverted. This app already has ads wired up
(`lib/core/ads.dart`, `ads_config.dart`). Add a one-time non-consumable
purchase (`remove_ads_offline`) that removes ads; "unlock full offline mode"
is marketing framing for this app's existing offline-first behaviour -- there
was no separate crippled offline feature to build, so nothing new was gated
there.

## This project's real Android toolchain (checked, not assumed)

From `railpariksha/app/android/app/build.gradle.kts` and
`railpariksha/app/android/build.gradle.kts` /
`.../gradle/wrapper/gradle-wrapper.properties` on this branch:

- AGP: **9.1.0**, Kotlin Gradle Plugin: **2.4.0**, Gradle: **9.3.1**
- The app's own `build.gradle.kts` already uses AGP 9's built-in-Kotlin
  model: no `id("kotlin-android")` plugin applied, just a top-level
  `kotlin { compilerOptions { ... } }` block.

This is the same bleeding-edge combination that broke `phosphor_flutter`
(this session, build-only failure) and that the earlier `home_widget`
evaluation declined over (a GitHub issue filed against this exact
AGP/Kotlin/Gradle combo).

## What research found for `in_app_purchase` / `in_app_purchase_android`

- `in_app_purchase` (official Flutter team package, `flutter.dev` verified
  publisher): latest `3.3.1`, published ~13 days before this check. Its
  changelog shows active upkeep (min SDK bumps, dependency bumps) but no
  AGP-9-specific entry -- because it apparently never needed one.
- Fetched the actual source of `in_app_purchase_android`'s
  `android/build.gradle.kts` from `flutter/packages` (main branch) directly,
  not a summary:
  ```
  plugins {
      id("com.android.library")
  }
  kotlin {
      compilerOptions {
          jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
      }
  }
  ```
  **No `kotlin-android` / `org.jetbrains.kotlin.android` plugin is applied.**
  This is exactly the built-in-Kotlin-compatible pattern this project's own
  `app/build.gradle.kts` already uses -- not the legacy pattern that broke
  `home_widget`, `wakelock_plus`, `camera_android_camerax`, and others
  tracked under `flutter/flutter#181383` ("[many] Flutter maintained plugins
  should support AGP 9.0").
- Searched that tracking issue and several related AGP-9/built-in-Kotlin
  issue threads specifically for `in_app_purchase` / `in_app_purchase_android`
  mentions: **none found**. The affected-plugin lists name
  `camera_android_camerax`, `wakelock_plus`, third-party SDKs (NewRelic,
  TelemetryDeck, tpay, RevenueCat's `purchases-flutter`), but not Flutter's
  own billing plugin.
- No version-exact GitHub issue (the kind of smoking-gun the `home_widget`
  eval found) turned up for this package against AGP 9.1.0/Kotlin
  2.4.0/Gradle 9.3.1.

## Why this is a go (with real caveats)

Unlike `home_widget`, the actual plugin source already matches this
project's own built-in-Kotlin style, and no credible version-specific
incompatibility report exists. This is a necessary dependency (no
first-party Play Billing without one), so the bar was "no red flag found,"
not "zero residual risk" -- a real Android build is still the only way to be
certain, and this sandbox has no Android SDK to run one.

## What was built

- `pubspec.yaml`: added `in_app_purchase: ^3.3.1`.
- `android/app/src/main/AndroidManifest.xml`: added
  `android.permission.com.android.vending.BILLING`.
- `lib/core/purchases.dart`: `PurchaseManager` -- queries the
  `remove_ads_offline` product, listens to the purchase stream, calls
  `restorePurchases()` once at startup, sets `Progress.removedAds = true` on
  a verified `purchased`/`restored` update, always completes pending
  purchases.
- `lib/data/progress.dart`: new persisted field `removedAds` (survives
  `reset()`, since it's an entitlement, not gamification state).
- Ad call sites gated on `!p.removedAds`: `AdBanner` and the rewarded
  freeze-token card in `progress_screen.dart`, `InterstitialAdManager.preload`
  in `quiz_screen.dart`, `InterstitialAdManager.showIfReady` in
  `results_screen.dart`.
- `lib/screens/me_screen.dart`: new "Premium" section (`_PremiumCard`) with a
  buy button (shows live price from Play), a restore-purchases action, and an
  "active" state once purchased -- follows the existing `ListTile`/`Card`
  conventions on that screen.
- `lib/core/app_scope.dart`, `lib/main.dart`: wired a single `PurchaseManager`
  instance through `AppScope`, initialized fire-and-forget after `runApp` so
  a slow/unavailable Play Billing connection never delays startup.

## What still needs a real build (cannot be done in this sandbox)

- No Android SDK / `flutter build apk --release` here -- confirm the build
  actually succeeds on a real machine or CI before shipping, same caveat as
  everything else attempted this session.
- Smoke-test the real purchase flow on a signed, Play-Console-uploaded build
  (test purchases don't work on debug-signed/unsigned builds).

## Manual Play Console steps (account owner only)

1. App must already have at least one release uploaded to an internal/closed
   test track (billing needs a Play Console app record either way).
2. Play Console -> your app -> **Monetize -> Products -> In-app products**.
3. Create a product:
   - Product ID: `remove_ads_offline` (must match `kRemoveAdsProductId` in
     `lib/core/purchases.dart` exactly).
   - Name/description: e.g. "Remove ads & unlock full offline mode".
   - Price: set per-market pricing.
   - Status: **Active**.
4. Add license testers (Play Console -> Setup -> License testing) with
   Gmail accounts, so they can complete a test purchase without being
   charged, before this goes to production.
5. The purchase only becomes testable once the APK/AAB that declares the
   `com.android.vending.BILLING` permission (already added) is uploaded to
   at least an internal test track and the tester has installed that build
   from Play (not a sideloaded APK).
