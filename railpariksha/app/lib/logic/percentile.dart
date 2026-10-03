import 'dart:math';

/// Estimates where a mock-test score likely falls among typical RRB/RPF
/// aspirants, as a rough statistical guide -- NOT a live ranking against other
/// users. This app is fully offline-first with no backend/server, so there is
/// no real peer data to rank against; showing a number without saying so would
/// be a fake social-proof claim. Every caller of [estimatedPercentile] must
/// label the result as an estimate (see ResultsScreen/ProgressScreen).
///
/// Modelled as a normal distribution over raw accuracy (correct/total, before
/// negative marking) with a mean and spread typical of competitive-exam MCQ
/// practice -- the same shape used across every exam, since RailPariksha has
/// no per-exam attempt volume of its own to fit a real distribution to.
const double _assumedMean = 0.45;
const double _assumedSd = 0.17;

/// Returns a 1-99 percentile: "your score beats an estimated N% of typical
/// attempts at this accuracy level". [correctFraction] is correct/total,
/// clamped to [0, 1].
int estimatedPercentile(double correctFraction) {
  final x = correctFraction.clamp(0.0, 1.0);
  final z = (x - _assumedMean) / _assumedSd;
  final p = _normalCdf(z) * 100;
  return p.round().clamp(1, 99);
}

double _normalCdf(double z) => 0.5 * (1 + _erf(z / sqrt2));

/// Abramowitz-Stegun 7.1.26 approximation (max error ~1.5e-7) -- avoids a
/// numerics package dependency for this one formula.
double _erf(double x) {
  const a1 = 0.254829592, a2 = -0.284496736, a3 = 1.421413741, a4 = -1.453152027, a5 = 1.061405429, p = 0.3275911;
  final sign = x < 0 ? -1.0 : 1.0;
  final ax = x.abs();
  final t = 1.0 / (1.0 + p * ax);
  final y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-ax * ax);
  return sign * y;
}
