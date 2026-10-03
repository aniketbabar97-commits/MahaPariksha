import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/progress.dart';

/// Non-consumable product id for the one-time "remove ads / unlock full
/// offline mode" purchase. Must match the product id created in Play
/// Console exactly -- see railpariksha/docs/IAP_EVAL.md for the manual
/// Play Console setup steps.
const kRemoveAdsProductId = 'remove_ads_offline';

/// Deliberate launch-strategy decision (not a bug, not a missing feature):
/// the first 3 months after launch are ads-only, no purchase option shown
/// at all, to prioritize growth/word-of-mouth over revenue while the user
/// base is still small. The real plan after that window is a recurring
/// ₹30/month subscription (NOT this one-time product -- a subscription
/// needs Play Billing's separate subscription API, renewal/grace-period
/// handling, etc., so building that is its own task when the time comes).
/// Flip this back to true (or just delete this flag and its one call site
/// in me_screen.dart) once that 3-month window is over and monetization
/// should go live again. Ads themselves are untouched by this flag -- they
/// keep running the whole time, this only hides the purchase entry point.
///
/// Deliberately non-`const`: a `const false` used in an `if` gets
/// constant-folded by the analyzer into a `dead_code` warning, which
/// `flutter analyze` (run in CI) treats as a build failure just like an
/// error.
final bool kShowPremiumPurchase = false;

/// Thin wrapper around the official `in_app_purchase` plugin for this app's
/// single non-consumable product. Owns the purchase stream for the whole
/// app lifetime; [Progress.removedAds] is the only thing call sites need to
/// check (see ads.dart call sites in progress_screen/quiz_screen/results_screen).
class PurchaseManager {
  final Progress progress;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool available = false;
  final Completer<void> _ready = Completer<void>();

  /// Completes once [init] has resolved product details (or given up) --
  /// the purchase card on MeScreen awaits this so it can show a brief
  /// loading state instead of an incorrect "unavailable" flash.
  Future<void> get ready => _ready.future;

  PurchaseManager(this.progress);

  /// Call once at startup, after `progress.load()`. Safe to call even when
  /// Play Billing is unavailable (emulator without Play Store, etc.) --
  /// everything below degrades to "purchase not offered" rather than
  /// throwing, so it never blocks app startup.
  Future<void> init() async {
    try {
      available = await _iap.isAvailable();
      if (!available) return;
      _sub = _iap.purchaseStream.listen(_onPurchaseUpdate, onError: (_) {});
      final response = await _iap.queryProductDetails({kRemoveAdsProductId});
      if (response.productDetails.isNotEmpty) {
        product = response.productDetails.first;
      }
      // Picks up a purchase made on another device, or one that completed
      // after this device lost connectivity mid-purchase.
      unawaited(_iap.restorePurchases());
    } catch (_) {
      // Network/Play Services hiccup: product stays null, buy button hides.
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  void dispose() => _sub?.cancel();

  Future<void> buy() async {
    final p = product;
    if (p == null) return;
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() => _iap.restorePurchases();

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID != kRemoveAdsProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          progress.update((p) => p.removedAds = true);
          if (purchase.pendingCompletePurchase) _iap.completePurchase(purchase);
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) _iap.completePurchase(purchase);
          break;
        case PurchaseStatus.pending:
          break;
      }
    }
  }
}
