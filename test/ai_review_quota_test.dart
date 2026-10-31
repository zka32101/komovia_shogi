import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/ai_review_quota_service.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:komovia_shogi/services/entitlement_service.dart';
import 'package:komovia_shogi/services/purchase_service.dart';
import 'package:komovia_shogi/views/screens/shogi_review_screen.dart';

import 'support/fake_purchase_service.dart';

void main() {
  group('AiReviewQuotaService', () {
    late FakeFirebaseFirestore db;
    late DateTime now;
    late AiReviewQuotaService service;

    setUp(() {
      db = FakeFirebaseFirestore();
      now = DateTime(2026, 10, 31, 10);
      service = AiReviewQuotaService(firestore: db, clock: () => now);
    });

    test('allows 3 per day, then refuses', () async {
      for (var i = 0; i < 3; i++) {
        expect(await service.tryConsume('u1'), isTrue);
      }
      expect(await service.tryConsume('u1'), isFalse);
      expect(await service.usedToday('u1'), 3);
    });

    test('writes date and count to users/{uid}/ai_review_quota/daily', () async {
      await service.tryConsume('u1');
      final doc = await db
          .collection('users')
          .doc('u1')
          .collection('ai_review_quota')
          .doc('daily')
          .get();
      expect(doc.data()!['count'], 1);
      expect(DateTime.parse(doc.data()!['date'] as String), now);
    });

    test('reads the legacy yyyy-MM-dd date written by PR #45', () async {
      await db.doc('users/u1/ai_review_quota/daily')
          .set({'date': '2026-10-31', 'count': 3});
      expect(await service.usedToday('u1'), 3);
      expect(await service.tryConsume('u1'), isFalse);
      now = DateTime(2026, 11, 1, 9);
      expect(await service.tryConsume('u1'), isTrue);
    });

    test('resets on a new day', () async {
      for (var i = 0; i < 3; i++) {
        await service.tryConsume('u1');
      }
      now = DateTime(2026, 11, 1, 0, 1);
      expect(await service.usedToday('u1'), 0);
      expect(await service.tryConsume('u1'), isTrue);
      expect(await service.usedToday('u1'), 1);
    });

    test('quota is per user', () async {
      for (var i = 0; i < 3; i++) {
        await service.tryConsume('u1');
      }
      expect(await service.tryConsume('u2'), isTrue);
    });
  });

  testWidgets('shows the daily-limit message when the quota is exhausted',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          consumeAiReviewQuotaProvider
              .overrideWithValue(() async => AiReviewAccess.limitReached),
        ],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShogiReviewScreen(),
        ),
      ),
    );
    await tester.tap(find.text('検討する'));
    await tester.pumpAndSettle();
    expect(find.text('本日のAI分析は上限（3回）に達しました。明日またお試しください'),
        findsOneWidget);
  });

  group('consumeAiReviewQuotaProvider', () {
    late FakeFirebaseFirestore db;
    late DateTime now;

    ProviderContainer container(String? uid) {
      now = DateTime.now();
      final c = ProviderContainer(overrides: [
        currentUidProvider.overrideWithValue(uid),
        aiReviewQuotaServiceProvider.overrideWithValue(
            AiReviewQuotaService(firestore: db, clock: () => now)),
        entitlementServiceProvider.overrideWithValue(
            EntitlementService(firestore: db, clock: () => now)),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => db = FakeFirebaseFirestore());

    test('free users get 3 per day', () async {
      final consume = container('u1').read(consumeAiReviewQuotaProvider);
      for (var i = 0; i < 3; i++) {
        expect(await consume(), AiReviewAccess.allowed);
      }
      expect(await consume(), AiReviewAccess.limitReached);
    });

    test('AI分析プラン holders are unlimited and do not consume quota',
        () async {
      final c = container('u1');
      await EntitlementService(firestore: db)
          .grantAiAnalysisPlan('u1', const Duration(days: 30));
      final consume = c.read(consumeAiReviewQuotaProvider);
      for (var i = 0; i < 10; i++) {
        expect(await consume(), AiReviewAccess.allowed);
      }
      expect(await c.read(aiReviewQuotaServiceProvider).usedToday('u1'), 0);
    });

    test('an expired AI分析プラン falls back to the free limit', () async {
      final c = container('u1');
      await db.doc('users/u1/entitlements/current').set({
        'aiAnalysisPlanEndDate':
            now.subtract(const Duration(days: 1)).toIso8601String(),
      });
      final consume = c.read(consumeAiReviewQuotaProvider);
      for (var i = 0; i < 3; i++) {
        await consume();
      }
      expect(await consume(), AiReviewAccess.limitReached);
    });

    test('premium alone does not lift the AI review limit', () async {
      final c = container('u1');
      await EntitlementService(firestore: db)
          .grantPremium('u1', const Duration(days: 30));
      final consume = c.read(consumeAiReviewQuotaProvider);
      for (var i = 0; i < 3; i++) {
        await consume();
      }
      expect(await consume(), AiReviewAccess.limitReached);
    });

    test('no uid is refused instead of unlimited', () async {
      expect(await container(null).read(consumeAiReviewQuotaProvider)(),
          AiReviewAccess.signInRequired);
    });
  });

  group('ShogiReviewScreen upsell', () {
    Widget app(List<Override> overrides) => ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            locale: Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ShogiReviewScreen(),
          ),
        );

    testWidgets('limit reached shows the AI分析プラン purchase button',
        (tester) async {
      await tester.pumpWidget(app([
        consumeAiReviewQuotaProvider
            .overrideWithValue(() async => AiReviewAccess.limitReached),
        purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
      ]));
      await tester.tap(find.text('検討する'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-analysis-plan-upsell-button')),
          findsOneWidget);
      expect(find.text('AI分析プランに加入（¥300）'), findsOneWidget);
    });

    testWidgets('upsell button buys the AI分析プラン product', (tester) async {
      final bought = <String>[];
      final fake = FakePurchaseService(onBuy: (s, p) {
        bought.add(p.id);
        s.emit([purchase(p.id, PurchaseStatus.canceled)]);
      });
      await tester.pumpWidget(app([
        currentUidProvider.overrideWithValue('u1'),
        consumeAiReviewQuotaProvider
            .overrideWithValue(() async => AiReviewAccess.limitReached),
        purchaseServiceProvider.overrideWithValue(fake),
      ]));
      await tester.tap(find.text('検討する'));
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('ai-analysis-plan-upsell-button')));
      await tester.pumpAndSettle();
        expect(bought, [PurchaseService.aiAnalysisMonthlyProductId]);
      expect(find.text('購入をキャンセルしました'), findsOneWidget);
    });

    testWidgets('no uid shows the sign-in-required message', (tester) async {
      await tester.pumpWidget(app([
        consumeAiReviewQuotaProvider
            .overrideWithValue(() async => AiReviewAccess.signInRequired),
      ]));
      await tester.tap(find.text('検討する'));
      await tester.pumpAndSettle();
      expect(find.textContaining('サインインが必要です'), findsOneWidget);
    });
  });
}
