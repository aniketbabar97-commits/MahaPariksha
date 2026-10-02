# Android home-screen widget ("Practice now") -- evaluation

**Decision: NOT implementing today. Recommend revisiting after `home_widget` ships
AGP-9/built-in-Kotlin support, or after this project's Android toolchain is pinned
to something older.**

## What was asked

A one-tap home-screen widget (logo + "Practice now" tap target, deep-linking into a
quick practice session), via the standard `home_widget` pub.dev package, which needs
a new Dart dependency plus native Android code (Kotlin `AppWidgetProvider`, XML
layout, `AndroidManifest.xml` `<receiver>`).

## This project's real Android toolchain (checked, not assumed)

From `railpariksha/app/android/settings.gradle.kts` and
`railpariksha/app/android/gradle/wrapper/gradle-wrapper.properties` on
`claude/railpariksha-app-setup-sjymqk`:

- Android Gradle Plugin (AGP): **9.1.0**
- Kotlin Gradle Plugin: **2.4.0**
- Gradle: **9.3.1**
- Build files are Kotlin DSL (`.kts`), `compileSdk`/`minSdk`/`targetSdk` all come
  from the Flutter tool's own defaults for the installed Flutter SDK.

These are very recent, "just released" toolchain versions -- the same category of
bleeding-edge combination that caused today's earlier `phosphor_flutter` failure.

## What research found

- `home_widget` latest release is **0.10.0**, published ~15 days ago -- actively
  maintained, popular (2.2k likes, 214k downloads, verified publisher). Not an
  abandoned package.
- However, GitHub issue
  [ABausG/home_widget#461](https://github.com/ABausG/home_widget/issues/461),
  filed against **exactly** `home_widget 0.10.0` + **AGP 9.1.0** + **Kotlin 2.4.0**
  + **Gradle 9.3.1** -- i.e. this project's exact versions -- reports that
  `home_widget` still applies the Kotlin Gradle Plugin the legacy way and has
  **not migrated to AGP 9's built-in-Kotlin model**. Flutter now prints a hard
  warning on this.
- That issue was closed as a duplicate of
  [#421](https://github.com/ABausG/home_widget/issues/421), which confirms: Flutter
  has only **temporarily** patched the tooling to tolerate plugins that still apply
  KGP the old way, and states plainly that **"this support will be removed in a
  future version of Flutter."** No fixed `home_widget` release exists yet.
- This is the same shape of problem as the `phosphor_flutter` incident earlier in
  this session: a package that looks healthy on paper (good pub score, recent
  release, passes `flutter analyze`/`flutter test`, since none of that exercises
  the Android Gradle build) but has a **documented, version-exact, real
  incompatibility with this project's actual Android toolchain** that only shows up
  during a native build -- which cannot be run in this sandbox (no Android SDK, no
  `flutter build`).

## Why this is a no-go right now

Two independent risk factors stack here, both flagged in advance as reasons to
decline: (1) a brand-new Dart dependency, the exact category that just burned this
session, and (2) native Android/Kotlin code this sandbox cannot compile-check at
all. Finding a GitHub issue reporting the identical AGP/Kotlin/Gradle version combo
already in use in this repo removes any need to guess -- it's a confirmed match, not
a theoretical worry. Shipping it today would mean committing Kotlin widget code that
cannot be verified to build, on top of a dependency with a known, currently-unfixed
build-tool incompatibility.

## What a safer version would need

- Wait for a `home_widget` release that adopts Flutter's built-in-Kotlin model (or
  switch to a competing package once one demonstrably supports AGP 9 built-in
  Kotlin), **or**
- Temporarily pin this project's AGP/Kotlin/Gradle to the last versions before the
  built-in-Kotlin requirement, build and test the widget there, then separately plan
  the toolchain upgrade -- not recommended, since it works against the rest of the
  app's toolchain.
- Either way, this needs a real environment with the Android SDK and a working
  `flutter build apk --release` (or an emulator/device test) to confirm before
  merging -- something this sandbox does not have, same caveat as everything else
  attempted in this session.

## Branding reference (for whenever this is implemented)

`railpariksha/app/lib/core/theme.dart`: primary `BrandColors.sky` = `#0B3D91`,
secondary `BrandColors.saffron` = `#F5B400`, matching
`flutter_native_splash` config in `pubspec.yaml`. Use these for the widget
background/accent when it is eventually built.
