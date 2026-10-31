import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/user_entitlements.dart';
import '../services/entitlement_service.dart';
import '../services/purchase_service.dart';
import 'auth_provider.dart';

/// komovia_goの`purchase_provider.dart`を将棋道向けに移植したもの。
/// 違いは権利の保存先（`users/{uid}`本体ではなく本人専用の
/// `users/{uid}/entitlements/current`、[EntitlementService]経由）だけ。

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => PurchaseService(),
);

final entitlementServiceProvider = Provider<EntitlementService>(
  (ref) => EntitlementService(),
);

String? _uidOrNull(Ref ref) {
  try {
    return ref.read(currentUidProvider);
  } catch (_) {
    return null; // Firebase未初期化など
  }
}

/// サインイン中ユーザーの購入権利。未サインイン・読み込み中は[UserEntitlements.none]。
final userEntitlementsProvider = StreamProvider<UserEntitlements>((ref) {
  String? uid;
  try {
    uid = ref.watch(currentUidProvider);
  } catch (_) {
    uid = null;
  }
  if (uid == null) return Stream.value(UserEntitlements.none);
  return ref.watch(entitlementServiceProvider).stream(uid);
});

/// プレミアムが現在有効か。
final isPremiumActiveProvider = Provider<bool>((ref) {
  final e = ref.watch(userEntitlementsProvider).value ?? UserEntitlements.none;
  return e.isPremiumActive(DateTime.now());
});

/// ストア上の商品情報（現地通貨の価格表示用）。未登録・未接続ならnull。
final subscriptionProductProvider =
    FutureProvider.family<ProductDetails?, SubscriptionPlan>((ref, plan) {
  return ref.watch(purchaseServiceProvider).fetchProduct(plan.productId);
});

/// purchaseStreamに届いた更新を処理する。購入/復元なら権利を付与して
/// 完了通知、エラー/キャンセルも完了通知（しないと毎回再配信される）。
/// 付与に失敗した購入は完了通知せず、次回起動時の再配信に任せる。
Future<void> handlePurchaseUpdates({
  required List<PurchaseDetails> purchases,
  required PurchaseService purchaseService,
  required EntitlementService entitlementService,
  required String? uid,
}) async {
  for (final purchase in purchases) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final plan = SubscriptionPlan.values
            .where((p) => p.productId == purchase.productID)
            .firstOrNull;
        if (plan == null || uid == null) break;
        try {
          await entitlementService.grantPremium(
            uid,
            plan.entitlementLength,
            skipIfAlreadyActive: true,
          );
          await purchaseService.completePurchase(purchase);
        } catch (_) {
          // 完了通知しない → ストアが再配信し、次の機会に再試行される。
        }
      case PurchaseStatus.error:
      case PurchaseStatus.canceled:
        await purchaseService.completePurchase(purchase);
      case PurchaseStatus.pending:
        break;
    }
  }
}

/// アプリ起動中ずっとpurchaseStreamを購読し、未完了の購入（Firestore書き込み
/// 失敗後の再配信や「購入を復元」の結果）を権利に反映する。アプリのルートで
/// 一度watchする。
final purchaseRecoveryProvider = Provider<void>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  final entitlementService = ref.watch(entitlementServiceProvider);
  StreamSubscription<List<PurchaseDetails>>? sub;
  try {
    sub = purchaseService.purchaseStream.listen(
      (purchases) => handlePurchaseUpdates(
        purchases: purchases,
        purchaseService: purchaseService,
        entitlementService: entitlementService,
        uid: _uidOrNull(ref),
      ),
      onError: (_) {},
    );
  } catch (_) {
    // プラグインが使えない環境（テスト・未対応プラットフォーム）では何もしない。
  }
  ref.onDispose(() => sub?.cancel());
});

/// 「購入を復元」。ストアに再配信を依頼し、[purchaseRecoveryProvider]が
/// 反映するのを少し待ってから、プレミアムが有効になったかを返す。
final restorePurchasesProvider = Provider<Future<bool> Function()>((ref) {
  return () async {
    final purchaseService = ref.read(purchaseServiceProvider);
    if (!await purchaseService.isAvailable()) {
      throw PurchaseUnavailableException('この端末では購入機能を利用できません。');
    }
    await purchaseService.restorePurchases();
    await Future<void>.delayed(ref.read(restoreSettleDelayProvider));
    final uid = _uidOrNull(ref);
    if (uid == null) return false;
    final e = await ref.read(entitlementServiceProvider).get(uid);
    return e.isPremiumActive(DateTime.now());
  };
});

/// 復元後に権利反映を待つ時間（テストで0に差し替える）。
final restoreSettleDelayProvider =
    Provider<Duration>((ref) => const Duration(seconds: 2));

/// プレミアムプランを購入する。
final purchaseSubscriptionProvider =
    Provider<Future<void> Function(SubscriptionPlan plan)>((ref) {
  return (plan) {
    final uid = _uidOrNull(ref);
    if (uid == null) {
      throw PurchaseUnavailableException('購入にはサインインが必要です。');
    }
    return runPurchaseFlow(
      purchaseService: ref.read(purchaseServiceProvider),
      productId: plan.productId,
      grant: () => ref
          .read(entitlementServiceProvider)
          .grantPremium(uid, plan.entitlementLength),
    );
  };
});

/// 対話的な購入フロー共通部。商品照会→購入開始→purchaseStreamで結果待ち
/// →権利付与→完了通知。ストア・商品が使えなければ
/// [PurchaseUnavailableException]（成功を装わない）。
Future<void> runPurchaseFlow({
  required PurchaseService purchaseService,
  required String productId,
  required Future<void> Function() grant,
  Duration timeout = const Duration(minutes: 5),
}) async {
  if (!await purchaseService.isAvailable()) {
    throw PurchaseUnavailableException('この端末では購入機能を利用できません。');
  }
  final product = await purchaseService.fetchProduct(productId);
  if (product == null) {
    throw PurchaseUnavailableException(
        'このプランは現在ご購入いただけません。しばらくしてから再度お試しください。');
  }

  final completer = Completer<PurchaseDetails>();
  final subscription = purchaseService.purchaseStream.listen(
    (purchases) {
      for (final purchase in purchases) {
        if (purchase.productID != product.id || completer.isCompleted) continue;
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            completer.complete(purchase);
          case PurchaseStatus.error:
            purchaseService.completePurchase(purchase);
            completer.completeError(purchase.error ?? Exception('Purchase failed'));
          case PurchaseStatus.canceled:
            purchaseService.completePurchase(purchase);
            completer.completeError(PurchaseCanceledException());
          case PurchaseStatus.pending:
            break;
        }
      }
    },
    onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    },
  );

  try {
    if (!await purchaseService.buy(product)) {
      throw Exception('Failed to start purchase flow');
    }
    final purchase = await completer.future.timeout(timeout);
    await grant();
    await purchaseService.completePurchase(purchase);
  } finally {
    await subscription.cancel();
  }
}
