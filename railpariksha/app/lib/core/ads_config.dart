/// AdMob ad unit IDs. Real IDs are from the RailPariksha AdMob account
/// (app ID ca-app-pub-9100209280220037~3428622385).
///
/// By default every build uses Google's official test ad unit IDs -- these
/// always serve a placeholder ad, never earn or cost real money, and are
/// safe to tap during development/testing without risking an AdMob policy
/// violation for invalid traffic on the real units. Only the actual Play
/// Store release build should see real ads: railpariksha_release.yml passes
/// --dart-define=USE_TEST_ADS=false to flip this for that build only.
const bool useTestAds = bool.fromEnvironment('USE_TEST_ADS', defaultValue: true);

class AdIds {
  // The real AdMob App ID goes in AndroidManifest.xml directly (it's fixed at
  // build time and, per Google's own guidance, is safe to ship even while ad
  // UNIT ids below are still pointed at test values -- the App ID alone
  // doesn't serve ads).

  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedInterstitial = 'ca-app-pub-3940256099942544/5354046379';
  static const _testNative = 'ca-app-pub-3940256099942544/2247696110';
  static const _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';

  static const _realBanner = 'ca-app-pub-9100209280220037/2115540719';
  static const _realInterstitial = 'ca-app-pub-9100209280220037/2039433371';
  static const _realRewardedInterstitial = 'ca-app-pub-9100209280220037/8210175773';
  static const _realRewarded = 'ca-app-pub-9100209280220037/5863214031';
  static const _realNative = 'ca-app-pub-9100209280220037/6357952333';
  static const _realAppOpen = 'ca-app-pub-9100209280220037/9686823258';

  static String get banner => useTestAds ? _testBanner : _realBanner;
  static String get interstitial => useTestAds ? _testInterstitial : _realInterstitial;
  static String get rewarded => useTestAds ? _testRewarded : _realRewarded;
  static String get rewardedInterstitial => useTestAds ? _testRewardedInterstitial : _realRewardedInterstitial;
  // native/appOpen are wired here for later use but not yet shown anywhere in
  // the app -- v1 only shows banner + interstitial (see docs/store/ADS.md).
  static String get native => useTestAds ? _testNative : _realNative;
  static String get appOpen => useTestAds ? _testAppOpen : _realAppOpen;
}
