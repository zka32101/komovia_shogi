import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/l10n/app_localizations.dart';
import 'package:komovia_shogi/services/notification_service.dart';
import 'package:komovia_shogi/services/shogi_pvp_game_service.dart';
import 'package:komovia_shogi/viewmodels/auth_provider.dart';
import 'package:komovia_shogi/viewmodels/notification_provider.dart';
import 'package:komovia_shogi/viewmodels/shogi_pvp_game_provider.dart';
import 'package:komovia_shogi/views/screens/shogi_pvp_game_screen.dart';
import 'package:komovia_shogi/views/screens/shogi_pvp_games_list_screen.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ShogiPvpGameService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    service = ShogiPvpGameService(firestore);
  });

  ProviderContainer container() => ProviderContainer(overrides: [
        shogiPvpGameServiceProvider.overrideWithValue(service),
        notificationServiceProvider
            .overrideWithValue(NotificationService(firestore: firestore)),
      ]);

  Future<String> seed({String sente = 'a', String gote = 'b'}) async =>
      (await service.createGame(
        senteUid: sente,
        senteDisplayName: 'Name-$sente',
        goteUid: gote,
        goteDisplayName: 'Name-$gote',
      ))
          .id;

  group('getActiveGamesFor', () {
    test('returns active games as either side, excluding finished/others',
        () async {
      final g1 = await seed(sente: 'a', gote: 'b');
      final g2 = await seed(sente: 'c', gote: 'a');
      final g3 = await seed(sente: 'a', gote: 'd');
      await seed(sente: 'x', gote: 'y');
      await service.resign(gameId: g3, uid: 'a');

      final games = await service.getActiveGamesFor('a');
      expect(games.map((g) => g.id).toSet(), {g1, g2});
    });
  });

  group('rematchShogiPvpGameProvider', () {
    Future<dynamic> rematch(ProviderContainer c, String gameId, String uid) async {
      final prev = (await service.getGame(gameId))!;
      return c.read(rematchShogiPvpGameProvider)(
        previous: prev,
        requesterUid: uid,
        notificationTitle: 't',
        notificationBody: 'b',
      );
    }

    test('swaps sides and notifies the opponent', () async {
      final id = await seed();
      await service.resign(gameId: id, uid: 'b');
      final game = await rematch(container(), id, 'a');

      expect(game, isNotNull);
      expect(game.id, isNot(id));
      expect(game.senteUid, 'b');
      expect(game.goteUid, 'a');
      expect(game.isActive, isTrue);
      final notes = await firestore
          .collection('notifications')
          .doc('b')
          .collection('items')
          .get();
      expect(notes.docs.single.data()['type'], 'pvp_challenge');
      expect((notes.docs.single.data()['data'] as Map)['gameId'], game.id);
    });

    test('either player can initiate', () async {
      final id = await seed();
      await service.resign(gameId: id, uid: 'a');
      final game = await rematch(container(), id, 'b');
      expect(game.senteUid, 'b');
      final notes = await firestore
          .collection('notifications')
          .doc('a')
          .collection('items')
          .get();
      expect(notes.docs, hasLength(1));
    });

    test('refuses an active game and non-participants', () async {
      final id = await seed();
      expect(await rematch(container(), id, 'a'), isNull);
      await service.resign(gameId: id, uid: 'a');
      expect(await rematch(container(), id, 'stranger'), isNull);
      expect((await firestore.collection('shogi_pvp_games').get()).docs,
          hasLength(1));
    });
  });

  Widget app(Widget home, String uid) => ProviderScope(
        overrides: [
          shogiPvpGameServiceProvider.overrideWithValue(service),
          notificationServiceProvider
              .overrideWithValue(NotificationService(firestore: firestore)),
          currentUidProvider.overrideWithValue(uid),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  group('ShogiPvpGamesListScreen', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(app(const ShogiPvpGamesListScreen(), 'a'));
      await tester.pumpAndSettle();
      expect(find.text('No active games'), findsOneWidget);
    });

    testWidgets('lists games and shows claim button only for stale ones',
        (tester) async {
      final fresh = await seed(sente: 'b', gote: 'a');
      final stale = await seed(sente: 'c', gote: 'a');
      await firestore.collection('shogi_pvp_games').doc(stale).update({
        'updatedAt':
            Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3))),
      });

      await tester.pumpWidget(app(const ShogiPvpGamesListScreen(), 'a'));
      await tester.pumpAndSettle();

      expect(find.text('vs Name-b'), findsOneWidget);
      expect(find.text('vs Name-c'), findsOneWidget);
      expect(find.byKey(Key('shogi_pvp_games_list_claim_$stale')),
          findsOneWidget);
      expect(find.byKey(Key('shogi_pvp_games_list_claim_$fresh')),
          findsNothing);

      await tester.ensureVisible(
          find.byKey(Key('shogi_pvp_games_list_claim_$stale')));
      await tester.tap(find.byKey(Key('shogi_pvp_games_list_claim_$stale')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect((await service.getGame(stale))!.result, 'forfeit');
      expect(find.text('vs Name-c'), findsNothing);
    });
  });

  group('ShogiPvpGameScreen rematch button', () {
    testWidgets('only shown after the game ends, and opens the new game',
        (tester) async {
      final id = await seed();
      await tester.pumpWidget(app(ShogiPvpGameScreen(gameId: id), 'a'));
      await tester.pump();
      expect(find.byKey(const Key('shogi_pvp_rematch_button')), findsNothing);

      await service.resign(gameId: id, uid: 'b');
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('shogi_pvp_rematch_button')), findsOneWidget);

      await tester.ensureVisible(
          find.byKey(const Key('shogi_pvp_rematch_button')));
      await tester.tap(find.byKey(const Key('shogi_pvp_rematch_button')));
      await tester.pumpAndSettle();
      final games = await firestore.collection('shogi_pvp_games').get();
      expect(games.docs, hasLength(2));
      expect(find.byKey(const Key('shogi_pvp_rematch_button')), findsNothing);
    });
  });
}
