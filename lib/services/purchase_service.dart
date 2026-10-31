import 'package:in_app_purchase/in_app_purchase.dart';

/// ペイウォールで販売するプレミアムプラン。現状は月額のみ
/// （年額・買い切りは今後の判断事項）。
enum SubscriptionPlan { monthly }

extension SubscriptionPlanProductId on SubscriptionPlan {
  String get productId => switch (this) {
        SubscriptionPlan.monthly => PurchaseService.premiumMonthlyProductId,
      };

  Duration get entitlementLength => switch (this) {
        SubscriptionPlan.monthly => const Duration(days: 30),
      };
}

/// プラットフォームの`in_app_purchase`プラグインの薄いラッパー
/// （komovia_goの`PurchaseService`と同じ形）。商品IDはApp Store Connect /
/// Play Consoleに登録されるまで購入できない。
///
/// [InAppPurchase.instance]は初回アクセス時まで触らない — テストでは
/// このクラスを継承したフェイクに差し替えるため。
class PurchaseService {
  PurchaseService({InAppPurchase? iap}) : _iapOverride = iap;

  static const String premiumMonthlyProductId = 'shogido_premium_monthly';
  static const Set<String> productIds = {premiumMonthlyProductId};

  final InAppPurchase? _iapOverride;
  InAppPurchase get _iap => _iapOverride ?? InAppPurchase.instance;

  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  Future<bool> isAvailable() => _iap.isAvailable();

  /// 商品のストア情報。ストアに繋がらない・未登録ならnull（例外にしない）。
  Future<ProductDetails?> fetchProduct(String productId) async {
    final response = await _iap.queryProductDetails({productId});
    if (response.error != null ||
        response.notFoundIDs.contains(productId) ||
        response.productDetails.isEmpty) {
      return null;
    }
    return response.productDetails.first;
  }

  /// 購入フローを開始する。結果は[purchaseStream]に非同期で届く。
  Future<bool> buy(ProductDetails product) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));

  /// 過去の購入を`restored`として[purchaseStream]へ再配信させる。
  /// App Store審査ガイドライン3.1.1により、明示的な「購入を復元」導線が必須。
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// ストアへの完了通知。これをしないと未処理扱いで返金される。
  Future<void> completePurchase(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase) return _iap.completePurchase(purchase);
    return Future.value();
  }
}

/// ストア・商品が利用できない（商品ID未登録など）ために購入できない。
/// ユーザーのキャンセルや決済失敗とは区別して、正直なメッセージを出すため。
class PurchaseUnavailableException implements Exception {
  PurchaseUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// ユーザーが購入をキャンセルした。
class PurchaseCanceledException implements Exception {
  @override
  String toString() => 'canceled';
}
