import 'package:flutter_test/flutter_test.dart';
import 'package:railpariksha/data/progress.dart';

void main() {
  test('text size round-trips and unknown values fall back to normal', () {
    final p = Progress()..textSize = 'large';
    expect(p.textBoost, 1.12);
    final q = Progress()..restoreFrom(p.toJson());
    expect(q.textSize, 'large');
    final bad = Progress()..restoreFrom({...p.toJson(), 'textSize': 'huge'});
    expect(bad.textSize, 'normal');
    expect((Progress()..textSize = 'xlarge').textBoost, 1.25);
    expect(Progress().textBoost, 1.0);
  });
}
