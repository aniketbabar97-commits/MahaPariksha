import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/progress.dart';

/// Non-consumable product id for the one-time "remove ads / unlock full
/// offline mode" purchase. Must match the product id created in Play
/// Console exactly -- see railpariksha/docs/IAP_EVAL.md for the manual
/// Play Console setup steps.
const kRemoveAdsProductId = 'remove_ads_offline';

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
