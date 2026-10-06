import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/core/ads_config.dart';

/// Real ads can't render in tests; this at least pins that every placement points at a unit of
/// the app's own AdMob app (publisher 9100209280220037) unless the build asked for test ads.
void main() {
  test('every ad unit id belongs to one publisher and is well-formed', () {
    final ids = {
      'banner': AdIds.banner,
      'interstitial': AdIds.interstitial,
      'rewarded': AdIds.rewarded,
      'rewardedInterstitial': AdIds.rewardedInterstitial,
      'native': AdIds.native,
      'appOpen': AdIds.appOpen,
    };
    final pattern = RegExp(r'^ca-app-pub-(\d{16})/(\d{10})$');
    final publishers = <String>{};
    for (final e in ids.entries) {
      final m = pattern.firstMatch(e.value);
      expect(m, isNotNull, reason: '${e.key} is not an AdMob unit id: ${e.value}');
      publishers.add(m!.group(1)!);
    }
    expect(publishers, hasLength(1), reason: 'test and real units must not be mixed: $ids');
    expect(publishers.single, anyOf('9100209280220037', '3940256099942544'));
    expect(ids.values.toSet(), hasLength(6), reason: 'two placements share a unit id');
  });
}
