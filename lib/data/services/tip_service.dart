import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Consumable Play Billing product IDs. Create these in Play Console
/// (Monetize > Products > In-app products) as managed, consumable products.
const tipProductIds = <String>{'tip_small', 'tip_medium', 'tip_large'};

/// A tip option shown to the user. [price] is localised by Google Play.
class TipProduct {
  final String id;
  final String price;
  final Object raw;
  const TipProduct({required this.id, required this.price, required this.raw});
}

enum TipResult { pending, success, cancelled, failed }

/// Voluntary developer tips via Google Play Billing. Unlocks nothing.
abstract interface class ITipService {
  Stream<TipResult> get events;
  Future<List<TipProduct>> loadProducts();
  Future<void> buy(TipProduct product);
  Future<void> dispose();
}

class PlayTipService implements ITipService {
  PlayTipService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final _events = StreamController<TipResult>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  Stream<TipResult> get events => _events.stream;

  @override
  Future<List<TipProduct>> loadProducts() async {
    if (kIsWeb || !Platform.isAndroid || !await _iap.isAvailable()) {
      return const [];
    }
    _sub ??= _iap.purchaseStream.listen(
      (list) => unawaited(_onPurchases(list)),
      onError: (_) => _events.add(TipResult.failed),
    );
    final response = await _iap.queryProductDetails(tipProductIds);
    final items =
        response.productDetails
            .map((d) => TipProduct(id: d.id, price: d.price, raw: d))
            .toList()
          ..sort(
            (a, b) => (a.raw as ProductDetails).rawPrice.compareTo(
              (b.raw as ProductDetails).rawPrice,
            ),
          );
    return items;
  }

  @override
  Future<void> buy(TipProduct product) async {
    final ok = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product.raw as ProductDetails,
      ),
    );
    if (!ok) _events.add(TipResult.failed);
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _events.add(TipResult.pending);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          // Must acknowledge/consume or Google refunds the purchase after 3 days.
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _events.add(TipResult.success);
        case PurchaseStatus.canceled:
          _events.add(TipResult.cancelled);
        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          _events.add(TipResult.failed);
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _events.close();
  }
}
