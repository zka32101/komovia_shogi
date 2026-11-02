import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/models/user_entitlements.dart';
import 'package:komovia_shogi/services/entitlement_service.dart';
import 'package:komovia_shogi/services/purchase_service.dart';
import 'package:komovia_shogi/src/cosmetics/avatar_frames.dart';
import 'package:komovia_shogi/viewmodels/auth_provider.dart';
import 'package:komovia_shogi/viewmodels/purchase_provider.dart';
import 'package:komovia_shogi/views/screens/paywall_screen.dart';

import 'support/fake_purchase_service.dart';

const _premium = PurchaseService.premiumMonthlyProductId;

void main() {
  late FakeFirebaseFirestore db;
  late DateTime now;
  late EntitlementService entitlements;

  setUp(() {
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 10, 31, 12);
    entitlements = EntitlementService(firestore: db, clock: () => now);
  });

  group('SubscriptionPlan (komovia_core)', () {
    test('monthly and annual map to Shogi product ids', () {
      expect(SubscriptionPlan.monthly.productId,
          PurchaseService.premiumMonthlyProductId);
      expect(SubscriptionPlan.annual.productId,
          PurchaseService.premiumAnnualProductId);
      expect(PurchaseService.premiumAnnualProductId, 'shogido_premium_annual');
      expect(PurchaseService.productIds,
          contains(PurchaseService.premiumAnnualProductId));
      expect(SubscriptionPlan.lifetime.productId, 'shogido_premium_lifetime');
      expect(PurchaseService.productIds,
          contains(PurchaseService.premiumLifetimeProductId));
    });

    test('monthly keeps the 30-day entitlement length', () {
      expect(
          SubscriptionPlan.monthly.entitlementLength, const Duration(days: 30));
    });

    test('purchase product id resolves back to monthly', () {
      final plan = SubscriptionPlan.values
          .where((p) => p.productId == PurchaseService.premiumMonthlyProductId)
          .single;
      expect(plan, SubscriptionPlan.monthly);
    });

    test('annual product id resolves back to annual with a 1-year length', () {
      final plan = SubscriptionPlan.values
          .where((p) => p.productId == PurchaseService.premiumAnnualProductId)
          .single;
      expect(plan, SubscriptionPlan.annual);
      expect(plan.entitlementLength, isNotNull);
      expect(plan.entitlementLength!.inDays, greaterThanOrEqualTo(365));
    });
  });

  group('UserEntitlements', () {
    test('active only before the end date', () {
      final e = UserEntitlements(premiumEndDate: DateTime(2026, 11, 1));
      expect(e.isPremiumActive(DateTime(2026, 10, 31)), isTrue);
      expect(e.isPremiumActive(DateTime(2026, 11, 2)), isFalse);
      expect(UserEntitlements.none.isPremiumActive(now), isFalse);
      expect(e.toEntitlement(DateTime(2026, 10, 31)).isActive, isTrue);
    });

    test('round-trips through json', () {
      final e = UserEntitlements(
          premiumStartDate: DateTime(2026, 10, 1),
          premiumEndDate: DateTime(2026, 10, 31));
      final r = UserEntitlements.fromJson(e.toJson());
      expect(r.premiumStartDate, e.premiumStartDate);
      expect(r.premiumEndDate, e.premiumEndDate);
    });
  });

  group('EntitlementService', () {
    test('grantPremium sets a 30-day window in the owner-only doc', () async {
      await entitlements.grantPremium('u1', const Duration(days: 30));
      final e = await entitlements.get('u1');
      expect(e.premiumEndDate, now.add(const Duration(days: 30)));
      final doc = await db.doc('users/u1/entitlements/current').get();
      expect(doc.exists, isTrue);
      expect((await db.doc('users/u1').get()).exists, isFalse);
    });

    test('skipIfAlreadyActive does not extend an active entitlement', () async {
      await entitlements.grantPremium('u1', const Duration(days: 30));
      now = now.add(const Duration(days: 10));
      final granted = await entitlements.grantPremium(
          'u1', const Duration(days: 30),
          skipIfAlreadyActive: true);
      expect(granted, isFalse);
      expect((await entitlements.get('u1')).premiumEndDate,
          DateTime(2026, 11, 30, 12));
    });

    test('skipIfAlreadyActive still grants after expiry', () async {
      await entitlements.grantPremium('u1', const Duration(days: 30));
      now = now.add(const Duration(days: 40));
      expect(
          await entitlements.grantPremium('u1', const Duration(days: 30),
              skipIfAlreadyActive: true),
          isTrue);
    });
  });

  group('買い切りプラン', () {
    const lifetime = PurchaseService.premiumLifetimeProductId;

    test('grants permanent premium plus the lifetime-exclusive frame',
        () async {
      final fake = FakePurchaseService();
      await handlePurchaseUpdates(
        purchases: [purchase(lifetime, PurchaseStatus.purchased)],
        purchaseService: fake,
        entitlementService: entitlements,
        uid: 'u1',
      );
      final e = await entitlements.get('u1');
      expect(e.isLifetime, isTrue);
      expect(e.isPremiumActive(now.add(const Duration(days: 365 * 50))),
          isTrue);
      expect(e.toEntitlement(now).isLifetime, isTrue);
      expect(e.unlockedFrameIds, contains(kLifetimeFrameId));
      expect(fake.completed, [lifetime]);
    });

    test('re-delivery is idempotent', () async {
      for (var i = 0; i < 2; i++) {
        await handlePurchaseUpdates(
          purchases: [purchase(lifetime, PurchaseStatus.restored)],
          purchaseService: FakePurchaseService(),
          entitlementService: entitlements,
          uid: 'u1',
        );
      }
      final e = await entitlements.get('u1');
      expect(e.unlockedFrameIds, {kLifetimeFrameId});
      expect(e.premiumStartDate, now);
    });

    test('monthly subscribers are not lifetime purchasers', () async {
      await entitlements.grantPremium('u1', const Duration(days: 30));
      final e = await entitlements.get('u1');
      expect(e.isLifetime, isFalse);
      expect(e.unlockedFrameIds, isEmpty);
    });
  });

  group('handlePurchaseUpdates', () {
    test('grants and completes a purchased/restored premium', () async {
      final fake = FakePurchaseService();
      await handlePurchaseUpdates(
        purchases: [purchase(_premium, PurchaseStatus.restored)],
        purchaseService: fake,
        entitlementService: entitlements,
        uid: 'u1',
      );
      expect((await entitlements.get('u1')).isPremiumActive(now), isTrue);
      expect(fake.completed, [_premium]);
    });

    test('completes errors/cancels without granting', () async {
      final fake = FakePurchaseService();
      await handlePurchaseUpdates(
        purchases: [
          purchase(_premium, PurchaseStatus.error),
          purchase(_premium, PurchaseStatus.canceled),
        ],
        purchaseService: fake,
        entitlementService: entitlements,
        uid: 'u1',
      );
      expect((await entitlements.get('u1')).isPremiumActive(now), isFalse);
      expect(fake.completed, hasLength(2));
    });

    test('leaves a purchase unacknowledged when there is no uid', () async {
      final fake = FakePurchaseService();
      await handlePurchaseUpdates(
        purchases: [purchase(_premium, PurchaseStatus.purchased)],
        purchaseService: fake,
        entitlementService: entitlements,
        uid: null,
      );
      expect(fake.completed, isEmpty);
    });
  });

  group('runPurchaseFlow', () {
    test('grants then completes on success', () async {
      final fake = FakePurchaseService(
        onBuy: (s, p) => s.emit([purchase(p.id, PurchaseStatus.purchased)]),
      );
      var granted = false;
      await runPurchaseFlow(
          purchaseService: fake,
          productId: _premium,
          grant: () async => granted = true);
      expect(granted, isTrue);
      expect(fake.completed, [_premium]);
    });

    test('throws PurchaseUnavailableException for an unknown product', () {
      final fake = FakePurchaseService(knownProducts: {});
      expect(
          runPurchaseFlow(
              purchaseService: fake, productId: _premium, grant: () async {}),
          throwsA(isA<PurchaseUnavailableException>()));
    });

    test('throws PurchaseCanceledException when the user cancels', () async {
      final fake = FakePurchaseService(
        onBuy: (s, p) => s.emit([purchase(p.id, PurchaseStatus.canceled)]),
      );
      await expectLater(
          runPurchaseFlow(
              purchaseService: fake, productId: _premium, grant: () async {}),
          throwsA(isA<PurchaseCanceledException>()));
    });
  });

  group('PaywallScreen', () {
    Widget app(FakePurchaseService fake) => ProviderScope(
          overrides: [
            currentUidProvider.overrideWithValue('u1'),
            purchaseServiceProvider.overrideWithValue(fake),
            entitlementServiceProvider.overrideWithValue(
                EntitlementService(firestore: db, clock: DateTime.now)),
            restoreSettleDelayProvider.overrideWithValue(Duration.zero),
          ],
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PaywallScreen(),
          ),
        );

    testWidgets('always shows a restore-purchases button', (tester) async {
      await tester.pumpWidget(app(FakePurchaseService()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('購入を復元'), 200);
      expect(find.text('購入を復元'), findsOneWidget);
      expect(find.byKey(const ValueKey('subscribe-button')), findsOneWidget);
    });

    testWidgets('restore with nothing to restore says so', (tester) async {
      final fake = FakePurchaseService();
      await tester.pumpWidget(app(fake));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('購入を復元'), 200);
      await tester.tap(find.text('購入を復元'));
      await tester.pumpAndSettle();
      expect(fake.restoreCalls, 1);
      expect(find.text('復元できる購入が見つかりませんでした'), findsOneWidget);
    });

    testWidgets('subscribing grants premium and shows the active state',
        (tester) async {
      final fake = FakePurchaseService(
        onBuy: (s, p) => s.emit([purchase(p.id, PurchaseStatus.purchased)]),
      );
      await tester.pumpWidget(app(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscribe-button')));
      await tester.pumpAndSettle();
      expect(find.text('ご購入ありがとうございます！'), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-active')), findsOneWidget);
    });

    testWidgets('shows monthly and annual plans with fallback prices',
        (tester) async {
      await tester.pumpWidget(app(FakePurchaseService(knownProducts: {})));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('plan-monthly')), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-annual')), findsOneWidget);
      expect(find.text('¥300/月'), findsOneWidget);
      expect(find.text('¥2,400/年'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-lifetime')), findsOneWidget);
      await tester.scrollUntilVisible(
          find.textContaining('¥990/月'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('¥990/月'), findsOneWidget);
    });

    testWidgets('selecting annual buys the annual product', (tester) async {
      final bought = <String>[];
      final fake = FakePurchaseService(
        onBuy: (s, p) {
          bought.add(p.id);
          s.emit([purchase(p.id, PurchaseStatus.purchased)]);
        },
      );
      await tester.pumpWidget(app(fake));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-annual')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscribe-button')));
      await tester.pumpAndSettle();
      expect(bought, [PurchaseService.premiumAnnualProductId]);
      expect(find.byKey(const ValueKey('premium-active')), findsOneWidget);
    });

    testWidgets('shows an honest message when the product is not configured',
        (tester) async {
      await tester.pumpWidget(app(FakePurchaseService(knownProducts: {})));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscribe-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('現在ご購入いただけません'), findsOneWidget);
    });
  });

  group('PaywallScreen lifetime', () {
    testWidgets('selecting lifetime buys it and shows the permanent state',
        (tester) async {
      final fake = FakePurchaseService(
          onBuy: (self, p) =>
              self.emit([purchase(p.id, PurchaseStatus.purchased)]));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('u1'),
          purchaseServiceProvider.overrideWithValue(fake),
          entitlementServiceProvider.overrideWithValue(
              EntitlementService(firestore: db, clock: DateTime.now)),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaywallScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-lifetime')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('subscribe-button')));
      await tester.tap(find.byKey(const ValueKey('subscribe-button')));
      await tester.pumpAndSettle();
      expect(fake.completed, [PurchaseService.premiumLifetimeProductId]);
      expect(find.text('買い切りプラン購入済み（永久にプレミアム有効）'), findsOneWidget);
      final e = await EntitlementService(firestore: db).get('u1');
      expect(e.unlockedFrameIds, contains(kLifetimeFrameId));
    });
  });

  group('AI分析プラン', () {
    test('is independent of premium', () async {
      await entitlements.grantAiAnalysisPlan('u1', const Duration(days: 30));
      final e = await entitlements.get('u1');
      expect(e.hasAiAnalysisPlan(now), isTrue);
      expect(e.isPremiumActive(now), isFalse);
      expect(e.hasAiAnalysisPlan(now.add(const Duration(days: 31))), isFalse);
    });

    test('recovery grants the AI plan product, not premium', () async {
      final fake = FakePurchaseService();
      await handlePurchaseUpdates(
        purchases: [
          purchase(PurchaseService.aiAnalysisMonthlyProductId,
              PurchaseStatus.restored)
        ],
        purchaseService: fake,
        entitlementService: entitlements,
        uid: 'u1',
      );
      final e = await entitlements.get('u1');
      expect(e.hasAiAnalysisPlan(now), isTrue);
      expect(e.isPremiumActive(now), isFalse);
      expect(fake.completed, [PurchaseService.aiAnalysisMonthlyProductId]);
    });
  });
}
