import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';

/// Call once at app startup, before runApp.
Future<void> initAds() => MobileAds.instance.initialize();

/// A banner ad that shows nothing until it has actually loaded, so it never
/// leaves a blank gap or shifts surrounding layout while loading or if the
/// load fails (e.g. offline -- this app is offline-first, so ads must fail
/// silently, never block or clutter the UI).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
        },
      ),
    );
    ad.load();
    _ad = ad;
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

/// Preloads and shows a single full-screen interstitial at a natural break
/// point (after a completed mock test, on the results screen) -- never on a
/// screen where the user is mid-task. [preload] is cheap to call repeatedly
/// (it no-ops if a load is already in flight or an ad is already ready) so
/// call sites don't need to track state themselves.
class InterstitialAdManager {
  static InterstitialAd? _ad;
  static bool _loading = false;

  /// First [_graceMocks] mocks are always ad-free (protects first-session
  /// retention while a new user is still forming the daily habit), then
  /// capped to every other mock after that -- an ad on literally every mock
  /// would fatigue this app's most engaged users, who take several a day.
  static const _graceMocks = 2;
  static bool shouldShowForMockCount(int mockCount) => mockCount > _graceMocks && mockCount.isOdd;

  static void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (_) => _loading = false,
      ),
    );
  }

  /// Shows the preloaded ad if one is ready; otherwise does nothing --
  /// results never wait on an ad load. Always preloads the next one so the
  /// next mock's results screen has a head start.
  static void showIfReady() {
    final ad = _ad;
    if (ad == null) return;
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preload();
      },
    );
    ad.show();
  }
}

/// Lets the user opt in to watching a rewarded ad for a concrete in-app
/// benefit (currently: a bonus streak-freeze token, see ProgressScreen) --
/// a "give me something, get something" exchange the user asks for, rather
/// than a forced interruption. Opt-in rewarded ads also typically earn a
/// higher eCPM than interstitials, so this is the preferred ad type
/// wherever a natural reward moment already exists in the UI.
class RewardedAdManager {
  static RewardedAd? _ad;
  static bool _loading = false;

  /// Rewarded loads that failed in a row (no fill, no network). Reset by any success.
  static int loadFailures = 0;

  static bool get isReady => _ad != null;

  /// No ad is ready and the last loads failed: there is nothing to wait for.
  static bool get unavailable => _ad == null && !_loading && loadFailures >= 2;

  static void preload() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          loadFailures = 0;
        },
        onAdFailedToLoad: (_) {
          _loading = false;
          loadFailures++;
        },
      ),
    );
  }

  /// Shows the preloaded ad and calls [onReward] once AdMob confirms a full
  /// watch (it only fires onUserEarnedReward after that, so no separate
  /// skip-and-claim guard is needed). Returns false and does nothing if no
  /// ad is ready yet -- callers should tell the user to try again shortly
  /// rather than block on a fresh load.
  static bool showIfReady({required void Function() onReward}) {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        preload();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => onReward());
    return true;
  }
}
