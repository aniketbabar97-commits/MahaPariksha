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
        onAdFailedToLoad: (ad, error) => ad.dispose(),
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
