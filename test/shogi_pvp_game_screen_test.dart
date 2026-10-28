import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/services/shogi_pvp_game_service.dart';
import 'package:komovia_shogi/viewmodels/auth_provider.dart';
import 'package:komovia_shogi/viewmodels/shogi_pvp_game_provider.dart';
import 'package:komovia_shogi/views/screens/shogi_pvp_game_screen.dart';

void main() {
  Future<String> seedGame(ShogiPvpGameService service) async {
    final game = await service.createGame(
      senteUid: 'sente-uid',
      senteDisplayName: 'Alice',
      goteUid: 'gote-uid',
      goteDisplayName: 'Bob',
    );
    return game.id;
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required String gameId,
    required ShogiPvpGameService service,
    required String uid,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shogiPvpGameServiceProvider.overrideWithValue(service),
          currentUidProvider.overrideWithValue(uid),
        ],
        child: MaterialApp(home: ShogiPvpGameScreen(gameId: gameId)),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the board and whose turn it is for sente', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ShogiPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'sente-uid');

    expect(find.text('あなたの番です'), findsOneWidget);
    expect(find.byKey(const Key('shogi_pvp_board_gesture_detector')), findsOneWidget);
    expect(find.text('投了する'), findsOneWidget);
  });

  testWidgets('shows the opponent is to move for gote', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = ShogiPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'gote-uid');

    expect(find.text('相手の番です'), findsOneWidget);
  });

  testWidgets('a legal tap-tap move is applied and the turn flips', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ShogiPvpGameService(firestore);
    final gameId = await seedGame(service);
    final shogiGame = ShogiGame();
    final firstLegal =
        shogiGame.legalMoves(shogiGame.initialPosition()).whereType<BoardMove>().first;

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'sente-uid');

    final boardFinder = find.byKey(const Key('shogi_pvp_board_gesture_detector'));
    final topLeft = tester.getTopLeft(boardFinder);
    final size = tester.getSize(boardFinder);
    final cellSize = size.width / 9;
    Offset centerOf(Square square) => topLeft +
        Offset(cellSize * (square.file + 0.5), cellSize * (square.rank + 0.5));

    await tester.tapAt(centerOf(firstLegal.from));
    await tester.pump();
    await tester.tapAt(centerOf(firstLegal.to));
    await tester.pump();
    await tester.pump();

    final fetched = await service.getGame(gameId);
    expect(fetched!.movesCount, 1);
    expect(find.text('相手の番です'), findsOneWidget);
  });

  testWidgets('resign ends the game and shows the loss message', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ShogiPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(tester, gameId: gameId, service: service, uid: 'sente-uid');

    await tester.tap(find.text('投了する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投了する').last);
    await tester.pumpAndSettle();

    expect(find.text('あなたの負けです'), findsOneWidget);
    expect(find.text('投了する'), findsNothing);
  });

  testWidgets('shows a spectator view for a non-participant uid', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ShogiPvpGameService(firestore);
    final gameId = await seedGame(service);

    await pumpScreen(
      tester,
      gameId: gameId,
      service: service,
      uid: 'someone-else',
    );

    expect(find.text('観戦中'), findsOneWidget);
    expect(find.text('投了する'), findsNothing);
  });

  testWidgets('shows a login-required message when signed out', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final service = ShogiPvpGameService(firestore);
    final gameId = await seedGame(service);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shogiPvpGameServiceProvider.overrideWithValue(service),
          currentUidProvider.overrideWithValue(null),
        ],
        child: MaterialApp(home: ShogiPvpGameScreen(gameId: gameId)),
      ),
    );
    await tester.pump();

    expect(find.text('ログインが必要です'), findsOneWidget);
  });
}
