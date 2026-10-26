import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/models/active_shogi_game.dart';
import 'package:komovia_shogi/services/active_shogi_game_service.dart';

void main() {
  group('ActiveShogiGameService', () {
    test('save then getActive round-trips the same fields', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveShogiGameService(firestore: firestore);
      final game = ActiveShogiGame(
        uid: 'u1',
        difficultyName: 'hard',
        kifMoves: '# KIF形式棋譜ファイル\n...',
      );

      await service.save(game);
      final fetched = await service.getActive('u1');

      expect(fetched, isNotNull);
      expect(fetched!.uid, 'u1');
      expect(fetched.difficultyName, 'hard');
      expect(fetched.kifMoves, game.kifMoves);
    });

    test('getActive returns null when nothing is saved', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveShogiGameService(firestore: firestore);

      expect(await service.getActive('nobody'), isNull);
    });

    test('clear removes the saved game', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveShogiGameService(firestore: firestore);
      await service.save(
        ActiveShogiGame(uid: 'u1', difficultyName: 'easy', kifMoves: ''),
      );

      await service.clear('u1');

      expect(await service.getActive('u1'), isNull);
    });

    test('saving again for the same uid overwrites rather than duplicating',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = ActiveShogiGameService(firestore: firestore);
      await service.save(
        ActiveShogiGame(uid: 'u1', difficultyName: 'easy', kifMoves: 'v1'),
      );
      await service.save(
        ActiveShogiGame(uid: 'u1', difficultyName: 'hard', kifMoves: 'v2'),
      );

      final fetched = await service.getActive('u1');
      expect(fetched!.kifMoves, 'v2');
      expect(fetched.difficultyName, 'hard');
    });
  });

  group('ActiveShogiGame.fromFirestore', () {
    test('falls back to defaults for a document missing newer fields',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('active_shogi_games').doc('u1').set({});
      final doc = await firestore
          .collection('active_shogi_games')
          .doc('u1')
          .get();

      final game = ActiveShogiGame.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );

      expect(game.uid, 'u1');
      expect(game.difficultyName, 'medium');
      expect(game.kifMoves, '');
    });
  });
}
