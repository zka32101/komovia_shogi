import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/services/shogi_pvp_game_service.dart';

void main() {
  group('ShogiPvpGameService', () {
    test('createGame persists an active game with sente to move', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);

      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
        matchId: 'm1',
      );

      expect(game.status, 'active');
      expect(game.isSenteTurn, isTrue);
      expect(game.movesCount, 0);
      expect(game.kifMoves, '');
      final fetched = await service.getGame(game.id);
      expect(fetched, isNotNull);
      expect(fetched!.senteUid, 'u1');
      expect(fetched.matchId, 'm1');
    });

    test('applyMove rejects a move from the player whose turn it is not',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );
      final shogiGame = ShogiGame();
      final firstLegal =
          shogiGame.legalMoves(shogiGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u2', // it's sente's (u1's) turn, not gote's
        move: firstLegal,
      );

      expect(applied, isFalse);
      final fetched = await service.getGame(game.id);
      expect(fetched!.movesCount, 0);
    });

    test('applyMove rejects a non-participant', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );
      final shogiGame = ShogiGame();
      final firstLegal =
          shogiGame.legalMoves(shogiGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'nobody',
        move: firstLegal,
      );

      expect(applied, isFalse);
    });

    test('applyMove rejects an illegal move', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );

      // A1 to A1 is never a legal move for anyone.
      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u1',
        move: const BoardMove(from: Square(0, 0), to: Square(0, 0)),
      );

      expect(applied, isFalse);
    });

    test('applyMove updates kifMoves, flips the turn, and increments movesCount',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );
      final shogiGame = ShogiGame();
      final firstLegal =
          shogiGame.legalMoves(shogiGame.initialPosition()).first;

      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u1',
        move: firstLegal,
      );

      expect(applied, isTrue);
      final fetched = await service.getGame(game.id);
      expect(fetched!.isSenteTurn, isFalse);
      expect(fetched.movesCount, 1);
      expect(fetched.kifMoves, isNotEmpty);
      expect(fetched.status, 'active');
    });

    test('applyMove is rejected once the game has finished', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );
      await service.resign(gameId: game.id, uid: 'u1');
      final shogiGame = ShogiGame();
      final firstLegal =
          shogiGame.legalMoves(shogiGame.initialPosition()).first;

      // u2's turn by game state, but the game is already finished.
      final applied = await service.applyMove(
        gameId: game.id,
        uid: 'u1',
        move: firstLegal,
      );

      expect(applied, isFalse);
    });

    test('resign by sente makes gote the winner', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );

      await service.resign(gameId: game.id, uid: 'u1');

      final fetched = await service.getGame(game.id);
      expect(fetched!.status, 'finished');
      expect(fetched.winnerUid, 'u2');
      expect(fetched.result, 'resignation');
    });

    test('resign by gote makes sente the winner', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );

      await service.resign(gameId: game.id, uid: 'u2');

      final fetched = await service.getGame(game.id);
      expect(fetched!.winnerUid, 'u1');
    });

    test('resign by a non-participant does nothing', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );

      await service.resign(gameId: game.id, uid: 'nobody');

      final fetched = await service.getGame(game.id);
      expect(fetched!.status, 'active');
    });

    test('resign on an already-finished game does not overwrite the result',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );
      await service.resign(gameId: game.id, uid: 'u1');

      // u2 tries to resign too, after the game already ended.
      await service.resign(gameId: game.id, uid: 'u2');

      final fetched = await service.getGame(game.id);
      expect(fetched!.winnerUid, 'u2'); // unchanged from the first resign
    });

    test('watchGame streams the current snapshot', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ShogiPvpGameService(firestore);
      final game = await service.createGame(
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
      );

      final emitted = await service.watchGame(game.id).first;

      expect(emitted.id, game.id);
      expect(emitted.senteUid, 'u1');
    });
  });
}
