import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:komovia_core/komovia_core.dart' show SubscriptionPlan, AiAnalysisPlan;

export 'package:komovia_core/komovia_core.dart'
    show
        SubscriptionPlan,
        SubscriptionPlanEntitlementLength,
        AiAnalysisPlan,
        AiAnalysisPlanEntitlementLength,
        PurchaseUnavailableException,
        PurchaseCanceledException;

/// ペイウォールで販売するプレミアムプランの商品ID。プラン型自体は
/// komovia_coreの[SubscriptionPlan]（monthly/annual/lifetime）を共有し、
/// 期間はcoreの`entitlementLength`を使う。将棋道が販売するのは月額・年額
/// （komovia_goと同じ価格帯）と、買い切り（永久プレミアム＋限定スキン/フレーム）。
extension SubscriptionPlanProductId on SubscriptionPlan {
  String? get productId => switch (this) {
        SubscriptionPlan.monthly => PurchaseService.premiumMonthlyProductId,
        SubscriptionPlan.annual => PurchaseService.premiumAnnualProductId,
        SubscriptionPlan.lifetime => PurchaseService.premiumLifetimeProductId,
      };
}

/// AI分析プラン — プレミアム（[SubscriptionPlan]）とは独立した別売りの月額商品
/// （¥990/月）。片方・両方・どちらも無し、のいずれもあり得るため、
/// komovia_goと同じくSubscriptionPlanの一種ではなく兄弟型にしている。
/// 型と期間（`entitlementLength`）はkomovia_coreの共有定義を使い、
/// 商品IDの対応だけをこのアプリで持つ。

extension AiAnalysisPlanProductId on AiAnalysisPlan {
  String get productId => switch (this) {
        AiAnalysisPlan.monthly => PurchaseService.aiAnalysisMonthlyProductId,
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
  static const String premiumAnnualProductId = 'shogido_premium_annual';
  static const String premiumLifetimeProductId = 'shogido_premium_lifetime';
  static const String aiAnalysisMonthlyProductId =
      'shogido_ai_analysis_monthly';
  static const Set<String> productIds = {
    premiumMonthlyProductId,
    premiumAnnualProductId,
    premiumLifetimeProductId,
    aiAnalysisMonthlyProductId,
  };

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
  Future<bool> buy(ProductDetails product) => _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product));

  /// 過去の購入を`restored`として[purchaseStream]へ再配信させる。
  /// App Store審査ガイドライン3.1.1により、明示的な「購入を復元」導線が必須。
  Future<void> restorePurchases() => _iap.restorePurchases();

  /// ストアへの完了通知。これをしないと未処理扱いで返金される。
  Future<void> completePurchase(PurchaseDetails purchase) {
    if (purchase.pendingCompletePurchase)
      return _iap.completePurchase(purchase);
    return Future.value();
  }
}

