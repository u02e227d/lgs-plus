import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import 'account_plan.dart';
import 'store_kit_bridge.dart';

class StoreBillingException implements Exception {
  const StoreBillingException(this.code);
  final String code;

  @override
  String toString() => code;
}

/// App Store 席位月額（Product ID は Connect と一致）
class StoreBilling {
  StoreBilling._();
  static final StoreBilling instance = StoreBilling._();

  static final _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Windows はアプリ内課金未対応（Apple StoreKit のみ）
  static bool get isStorePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static String? appAccountToken(String? raw) {
    final id = raw?.trim() ?? '';
    if (id.isEmpty || !_uuidRe.hasMatch(id)) return null;
    return id;
  }

  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<void> attach(
    Future<void> Function(PurchaseDetails purchase) onPaid,
  ) async {
    await _sub?.cancel();
    _sub = InAppPurchase.instance.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        if (!AccountPlan.productIds.contains(p.productID)) continue;
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          await onPaid(p);
        }
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
      }
    });
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> buy({
    required String productId,
    String? applicationUserName,
  }) async {
    if (!isStorePlatform) {
      throw const StoreBillingException('store_platform');
    }
    final store = InAppPurchase.instance;
    if (!await store.isAvailable()) {
      throw const StoreBillingException('store_unavailable');
    }
    var product = await _findProductRetry(store, productId);
    if (product == null) {
      try {
        await syncAppStoreCatalog();
      } catch (_) {}
      product = await _findProductRetry(store, productId);
    }
    if (product == null) {
      throw const StoreBillingException('store_product_missing');
    }
    final ok = await store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: appAccountToken(applicationUserName),
      ),
    );
    if (!ok) {
      throw const StoreBillingException('store_buy_failed');
    }
  }

  Future<ProductDetails?> _findProductRetry(
    InAppPurchase store,
    String productId,
  ) async {
    for (var i = 0; i < 4; i++) {
      if (i > 0) {
        await Future<void>.delayed(Duration(seconds: 2 * i));
      }
      final found = await _findProduct(store, productId);
      if (found != null) return found;
    }
    return null;
  }

  Future<ProductDetails?> _findProduct(
    InAppPurchase store,
    String productId,
  ) async {
    final ids = {
      for (final p in AccountPlan.storeSeatPacks) p.productId,
      productId,
      AccountPlan.legacyMonthlyProductId,
    };
    final response = await store.queryProductDetails(ids);
    for (final p in response.productDetails) {
      if (p.id == productId) return p;
    }
    return null;
  }

  Future<void> restore() async {
    if (!isStorePlatform) {
      throw const StoreBillingException('store_platform');
    }
    await InAppPurchase.instance.restorePurchases();
  }

  static Future<void> openManageSubscriptions() async {
    final uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
