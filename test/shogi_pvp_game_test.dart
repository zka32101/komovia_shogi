import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/models/shogi_pvp_game.dart';

void main() {
  group('ShogiPvpGame', () {
    test('playerColorOf identifies sente/gote/neither', () {
      final game = ShogiPvpGame(
        id: 'g1',
        senteUid: 'sente-uid',
        senteDisplayName: '先手プレイヤー',
        goteUid: 'gote-uid',
        goteDisplayName: '後手プレイヤー',
        isSenteTurn: true,
        movesCount: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(game.playerColorOf('sente-uid'), 1);
      expect(game.playerColorOf('gote-uid'), 2);
      expect(game.playerColorOf('nobody'), 0);
    });

    test('isTurnOf reflects isSenteTurn for each player', () {
      final game = ShogiPvpGame(
        id: 'g1',
        senteUid: 'sente-uid',
        senteDisplayName: '先手プレイヤー',
        goteUid: 'gote-uid',
        goteDisplayName: '後手プレイヤー',
        isSenteTurn: true,
        movesCount: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );

      expect(game.isTurnOf('sente-uid'), isTrue);
      expect(game.isTurnOf('gote-uid'), isFalse);
      expect(game.isTurnOf('nobody'), isFalse);
    });

    test('isActive/isFinished reflect status', () {
      final base = ShogiPvpGame(
        id: 'g1',
        senteUid: 's',
        senteDisplayName: '先手',
        goteUid: 'g',
        goteDisplayName: '後手',
        isSenteTurn: true,
        movesCount: 0,
        status: 'active',
        createdAt: DateTime.now(),
      );
      expect(base.isActive, isTrue);
      expect(base.isFinished, isFalse);

      final finished = ShogiPvpGame(
        id: 'g1',
        senteUid: 's',
        senteDisplayName: '先手',
        goteUid: 'g',
        goteDisplayName: '後手',
        isSenteTurn: true,
        movesCount: 10,
        status: 'finished',
        winnerUid: 's',
        result: 'resignation',
        createdAt: DateTime.now(),
      );
      expect(finished.isActive, isFalse);
      expect(finished.isFinished, isTrue);
    });
  });

  group('ShogiPvpGame.fromFirestore / toFirestore', () {
    test('round-trips through Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final ref = firestore.collection('shogi_pvp_games').doc();
      final game = ShogiPvpGame(
        id: ref.id,
        senteUid: 'u1',
        senteDisplayName: 'Alice',
        goteUid: 'u2',
        goteDisplayName: 'Bob',
        kifMoves: '# KIF形式棋譜ファイル\n...',
        isSenteTurn: false,
        movesCount: 3,
        status: 'active',
        matchId: 'm1',
        createdAt: DateTime(2026, 1, 1),
      );

      await ref.set(game.toFirestore());
      final doc = await ref.get();
      final fetched = ShogiPvpGame.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );

      expect(fetched.id, ref.id);
      expect(fetched.senteUid, 'u1');
      expect(fetched.goteUid, 'u2');
      expect(fetched.kifMoves, game.kifMoves);
      expect(fetched.isSenteTurn, isFalse);
      expect(fetched.movesCount, 3);
      expect(fetched.matchId, 'm1');
    });

    test('falls back to defaults for a document missing fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('shogi_pvp_games').doc('g1').set({});
      final doc = await firestore.collection('shogi_pvp_games').doc('g1').get();

      final game = ShogiPvpGame.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );

      expect(game.id, 'g1');
      expect(game.kifMoves, '');
      expect(game.isSenteTurn, isTrue);
      expect(game.movesCount, 0);
      expect(game.status, 'active');
      expect(game.winnerUid, isNull);
      expect(game.result, isNull);
      expect(game.matchId, isNull);
    });
  });
}
