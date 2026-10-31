import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/ai_review_quota_service.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:komovia_shogi/views/screens/shogi_review_screen.dart';

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
      expect(doc.data(), {'date': '2026-10-31', 'count': 1});
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
          consumeAiReviewQuotaProvider.overrideWithValue(() async => false),
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
}
