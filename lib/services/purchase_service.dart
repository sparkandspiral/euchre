import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:solitaire/providers/save_state_notifier.dart';

const _kProductRemoveAds = 'remove_ads_cards';
const _kProductRemoveAdsUnlimitedHints = 'remove_ads_and_unlimited_hints_cards';
const _kProductHints100 = 'one_hundred_hints_cards';

final purchaseServiceProvider =
    Provider<PurchaseService>((ref) => PurchaseService(ref));

class PurchaseService {
  PurchaseService(this._ref);

  final Ref _ref;
  final InAppPurchase _iap = InAppPurchase.instance;

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> loadProducts() async {
    final response = await _iap.queryProductDetails({
      _kProductRemoveAds,
      _kProductRemoveAdsUnlimitedHints,
      _kProductHints100,
    });
    if (response.error != null) {
      debugPrint('IAP query error: ${response.error}');
    }
    return response.productDetails;
  }

  Future<void> buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    if (product.id == _kProductHints100) {
      await _iap.buyConsumable(purchaseParam: purchaseParam);
    } else {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        return;
      case PurchaseStatus.error:
        debugPrint('Purchase error: ${purchase.error}');
        return;
      case PurchaseStatus.canceled:
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _applyEntitlement(purchase.productID);
        break;
    }
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  Future<void> _applyEntitlement(String productId) async {
    final notifier = _ref.read(saveStateNotifierProvider.notifier);
    if (productId == _kProductRemoveAds) {
      await notifier.setAdsRemoved();
    } else if (productId == _kProductRemoveAdsUnlimitedHints) {
      await notifier.setAdsRemoved();
      await notifier.setUnlimitedHints();
    } else if (productId == _kProductHints100) {
      await notifier.addHints(100);
    }
  }
}

