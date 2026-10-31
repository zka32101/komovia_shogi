import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/models/shogi_pvp_game.dart';
import 'package:komovia_shogi/services/shogi_pvp_game_service.dart';
import 'package:komovia_shogi/viewmodels/auth_provider.dart';
import 'package:komovia_shogi/viewmodels/shogi_pvp_game_provider.dart';
import 'package:komovia_shogi/views/screens/shogi_pvp_game_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const policy = ShogiPvpGameService.abandonmentPolicy;

  ShogiPvpGame game({
    bool isSenteTurn = true,
    String status = 'active',
    required DateTime updatedAt,
  }) =>
      ShogiPvpGame(
        id: 'g',
        senteUid: 's',
        senteDisplayName: 'S',
        goteUid: 'g2',
        goteDisplayName: 'G',
        isSenteTurn: isSenteTurn,
        movesCount: 0,
        status: status,
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );

  group('ShogiPvpGame.canClaimAbandonmentForfeit', () {
    final t0 = DateTime.utc(2026, 1, 1);
    test('threshold is 24 hours', () {
      expect(policy.threshold, const Duration(hours: 24));
    });
    test('waiting player can claim only after the threshold', () {
      final g = game(updatedAt: t0); // sente to move, gote waiting
      expect(
          g.canClaimAbandonmentForfeit('g2',
              policy: policy, now: t0.add(const Duration(hours: 23))),
          isFalse);
      expect(
          g.canClaimAbandonmentForfeit('g2',
              policy: policy, now: t0.add(const Duration(hours: 24))),
          isTrue);
    });
    test('player whose turn it is cannot claim', () {
      expect(
          game(updatedAt: t0).canClaimAbandonmentForfeit('s',
              policy: policy, now: t0.add(const Duration(days: 5))),
          isFalse);
    });
    test('non-participant and finished games cannot claim', () {
      final later = t0.add(const Duration(days: 5));
      expect(
          game(updatedAt: t0)
              .canClaimAbandonmentForfeit('x', policy: policy, now: later),
          isFalse);
      expect(
          game(updatedAt: t0, status: 'finished')
              .canClaimAbandonmentForfeit('g2', policy: policy, now: later),
          isFalse);
    });
  });

  group('ShogiPvpGameService.claimAbandonmentForfeit', () {
    Future<(FakeFirebaseFirestore, ShogiPvpGameService, String)> seed(
        {Duration age = const Duration(hours: 30)}) async {
      final fs = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(fs);
      final g = await service.createGame(
        senteUid: 's',
        senteDisplayName: 'S',
        goteUid: 'g2',
        goteDisplayName: 'G',
      );
      await fs.collection('shogi_pvp_games').doc(g.id).update({
        'updatedAt': Timestamp.fromDate(DateTime.now().subtract(age)),
      });
      return (fs, service, g.id);
    }

    test('waiting player wins a stale game by forfeit', () async {
      final (_, service, id) = await seed();
      expect(
          await service.claimAbandonmentForfeit(gameId: id, claimantUid: 'g2'),
          isTrue);
      final g = await service.getGame(id);
      expect(g!.status, 'finished');
      expect(g.winnerUid, 'g2');
      expect(g.result, 'forfeit');
    });

    test('rejected when not stale enough', () async {
      final (_, service, id) = await seed(age: const Duration(hours: 1));
      expect(
          await service.claimAbandonmentForfeit(gameId: id, claimantUid: 'g2'),
          isFalse);
      expect((await service.getGame(id))!.isActive, isTrue);
    });

    test('rejected for the player whose turn it is', () async {
      final (_, service, id) = await seed();
      expect(
          await service.claimAbandonmentForfeit(gameId: id, claimantUid: 's'),
          isFalse);
    });

    test('never overwrites an already-resigned game', () async {
      final (_, service, id) = await seed();
      await service.resign(gameId: id, uid: 'g2');
      expect(
          await service.claimAbandonmentForfeit(gameId: id, claimantUid: 'g2'),
          isFalse);
      expect((await service.getGame(id))!.result, 'resignation');
    });
  });

  group('ShogiPvpGameScreen forfeit button', () {
    Future<(ShogiPvpGameService, String)> seed(Duration age) async {
      final fs = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(fs);
      final g = await service.createGame(
        senteUid: 's',
        senteDisplayName: 'S',
        goteUid: 'g2',
        goteDisplayName: 'G',
      );
      await fs.collection('shogi_pvp_games').doc(g.id).update({
        'updatedAt': Timestamp.fromDate(DateTime.now().subtract(age)),
      });
      return (service, g.id);
    }

    Future<void> pump(WidgetTester tester, ShogiPvpGameService service,
        String id, String uid) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          shogiPvpGameServiceProvider.overrideWithValue(service),
          currentUidProvider.overrideWithValue(uid),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ShogiPvpGameScreen(gameId: id),
        ),
      ));
      await tester.pump();
    }

    const buttonKey = Key('shogi_pvp_claim_forfeit_button');

    testWidgets('hidden while the game is fresh', (tester) async {
      final (service, id) = await seed(const Duration(hours: 1));
      await pump(tester, service, id, 'g2');
      expect(find.byKey(buttonKey), findsNothing);
    });

    testWidgets('hidden for the player whose turn it is', (tester) async {
      final (service, id) = await seed(const Duration(hours: 30));
      await pump(tester, service, id, 's');
      expect(find.byKey(buttonKey), findsNothing);
    });

    testWidgets('waiting player can claim after confirming', (tester) async {
      final (service, id) = await seed(const Duration(hours: 30));
      await pump(tester, service, id, 'g2');
      expect(find.byKey(buttonKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      final after = await service.getGame(id);
      expect(after!.result, 'forfeit');
      expect(after.winnerUid, 'g2');
      await tester.pump();
      expect(find.text('相手の放置により不戦勝となりました'), findsOneWidget);
      expect(find.byKey(buttonKey), findsNothing);
    });
  });
}
