import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../logic/quiz_builder.dart' show QuizMode;
import 'ads_config.dart';
import 'app_scope.dart';

/// Call once at app startup, before runApp.
Future<void> initAds() => MobileAds.instance.initialize();

/// An anchored adaptive banner (sized to the screen width, which AdMob fills better and pays more
/// than a fixed 320x50). It shows nothing until it has actually loaded, so it never leaves a
/// blank gap or shifts the layout while loading or if the load fails (e.g. offline -- this app
/// is offline-first, so ads must fail silently, never block or clutter the UI). Once loaded it is
/// labelled and spaced away from the content around it, so it can't be mistaken for a button.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final width = (MediaQuery.of(context).size.width - 32).truncate();
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ?? AdSize.banner;
      if (!mounted) return;
      final ad = BannerAd(
        adUnitId: AdIds.banner,
        size: size,
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
      _ad = ad;
      await ad.load();
    } catch (_) {
      // No ads plugin / no network: stay invisible.
    }
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(context.tr('विज्ञापन', 'Advertisement'),
            style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          alignment: Alignment.center,
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ]),
    );
  }
}

/// A small native ad card for list screens (between rows, with generous spacing). Shows nothing
/// until loaded and when it fails, like [AdBanner]. Callers only add it for users who haven't
/// bought ad removal.
class NativeAdTile extends StatefulWidget {
  const NativeAdTile({super.key});

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    try {
      final ad = NativeAd(
        adUnitId: AdIds.native,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.small),
        listener: NativeAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            _ad = null;
          },
        ),
      );
      _ad = ad;
      ad.load();
    } catch (_) {
      // No ads plugin: stay invisible.
    }
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}

/// When an interstitial may appear, as a pure rule so it can be tested.
///
/// A completed quiz or paper is a natural break (never mid-question). The first
/// [graceQuizzes] are ad-free, which protects the first session while the daily habit forms;
/// after that every [every]th completion shows one, and never closer than [minGap] to the last.
class AdPacing {
  static const graceQuizzes = 2;
  static const every = 3;
  static const minGap = Duration(minutes: 3);
  static DateTime? _lastShown;

  /// Modes that end in a results screen worth an ad. The placement quiz is onboarding and the
  /// 60-second speed round is too short to interrupt.
  static bool eligibleMode(QuizMode m) => m != QuizMode.placement && m != QuizMode.speed;

  /// Whether the [completed]th quiz (1 for a user's first) is one that earns an ad, before the
  /// minimum gap is considered. Used to preload only when an ad is actually going to be shown;
  /// requests that are never shown drag down an ad unit's show rate and fill.
  static bool due(int completed) => completed > graceQuizzes && completed % every == 0;

  static bool shouldShow(int completed, {DateTime? now}) {
    if (!due(completed)) return false;
    final last = _lastShown;
    return last == null || (now ?? DateTime.now()).difference(last) >= minGap;
  }

  static void markShown([DateTime? now]) => _lastShown = now ?? DateTime.now();

  @visibleForTesting
  static void reset() => _lastShown = null;
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
  static bool showIfReady() {
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
    ad.show();
    return true;
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
