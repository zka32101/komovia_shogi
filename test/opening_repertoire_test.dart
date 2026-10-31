import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/models/opening_repertoire.dart';
import 'package:komovia_shogi/services/repertoire_service.dart';

RepertoireLine _line(List<String> moves, {String id = 'l1'}) =>
    RepertoireLine(id: id, name: 'test', moves: moves);

void main() {
  group('RepertoireMoveCodec', () {
    test('round-trips every legal move from the initial position', () {
      final game = ShogiGame();
      for (final m in game.legalMoves(game.initialPosition())) {
        final usi = RepertoireMoveCodec.toUsi(m);
        expect(
            RepertoireMoveCodec.toUsi(RepertoireMoveCodec.fromUsi(usi)), usi);
      }
    });

    test('encodes 7g7f, promotions and drops', () {
      expect(RepertoireMoveCodec.toUsi(RepertoireMoveCodec.fromUsi('7g7f')),
          '7g7f');
      final promo = RepertoireMoveCodec.fromUsi('8h2b+') as BoardMove;
      expect(promo.promote, isTrue);
      expect(RepertoireMoveCodec.toUsi(promo), '8h2b+');
      final drop = RepertoireMoveCodec.fromUsi('P*5e') as DropMove;
      expect(drop.pieceType, 'pawn');
      expect(RepertoireMoveCodec.toUsi(drop), 'P*5e');
    });

    test('formats Japanese notation', () {
      final game = ShogiGame();
      expect(
        RepertoireMoveCodec.toJapanese(
          game.initialPosition(),
          RepertoireMoveCodec.fromUsi('7g7f'),
        ),
        '▲７六歩',
      );
    });
  });

  group('RepertoireLine.isDueForReview', () {
    final now = DateTime(2026, 10, 31);
    test('never practiced is due', () {
      expect(_line(['7g7f']).isDueForReview(now), isTrue);
    });
    test('recently and correctly practiced is not due', () {
      final l = _line(['7g7f']).recordPractice(
        correctFirstTry: true,
        at: now.subtract(const Duration(days: 1)),
      );
      expect(l.isDueForReview(now), isFalse);
      expect(l.timesPracticed, 1);
      expect(l.timesCorrectFirstTry, 1);
    });
    test('last attempt wrong is due', () {
      final l = _line(['7g7f']).recordPractice(correctFirstTry: false, at: now);
      expect(l.isDueForReview(now), isTrue);
      expect(l.timesCorrectFirstTry, 0);
    });
    test('stale practice is due', () {
      final l = _line(['7g7f']).recordPractice(
        correctFirstTry: true,
        at: now.subtract(RepertoireLine.reviewInterval),
      );
      expect(l.isDueForReview(now), isTrue);
    });
  });

  group('RepertoireTrainer', () {
    test('sente: wrong move is rejected, correct moves advance with replies',
        () {
      final t = RepertoireTrainer(
        line: _line(['7g7f', '3c3d', '2g2f']),
        side: Side.first,
      );
      expect(t.ply, 0);
      expect(RepertoireMoveCodec.toUsi(t.expectedMove!), '7g7f');
      expect(t.submit(RepertoireMoveCodec.fromUsi('2g2f')),
          RepertoireAnswer.wrong);
      expect(t.ply, 0);
      expect(t.mistakes, 1);
      expect(t.submit(RepertoireMoveCodec.fromUsi('7g7f')),
          RepertoireAnswer.correct);
      // opponent's 3c3d auto-played
      expect(t.ply, 2);
      expect(t.submit(RepertoireMoveCodec.fromUsi('2g2f')),
          RepertoireAnswer.finished);
      expect(t.isFinished, isTrue);
      expect(t.completedWithoutMistakes, isFalse);
    });

    test('gote: the opening sente move is played automatically', () {
      final t =
          RepertoireTrainer(line: _line(['7g7f', '3c3d']), side: Side.second);
      expect(t.ply, 1);
      expect(t.position.sideToMove, Side.second);
      expect(t.submit(RepertoireMoveCodec.fromUsi('3c3d')),
          RepertoireAnswer.finished);
      expect(t.completedWithoutMistakes, isTrue);
    });
  });

  group('RepertoireService', () {
    test('create, save lines, record practice, rename, delete', () async {
      final fs = FakeFirebaseFirestore();
      final s = RepertoireService(firestore: fs);
      final rep = await s.createRepertoire('u1', name: '矢倉', side: Side.first);
      await s.saveLine('u1', rep.id, _line(['7g7f', '8c8d']));
      await s.saveLine('u1', rep.id, _line(['2g2f'], id: 'l2'));
      var loaded = (await s.getRepertoire('u1', rep.id))!;
      expect(loaded.name, '矢倉');
      expect(loaded.side, Side.first);
      expect(loaded.lines.map((l) => l.moves), [
        ['7g7f', '8c8d'],
        ['2g2f'],
      ]);

      final at = DateTime(2026, 10, 30, 12);
      await s.recordPractice('u1', rep.id, 'l1', correctFirstTry: true, at: at);
      loaded = (await s.getRepertoire('u1', rep.id))!;
      expect(loaded.lines.first.timesPracticed, 1);
      expect(loaded.lines.first.lastPracticedAt, at);
      expect(loaded.lines.first.lastAttemptCorrect, isTrue);
      expect(loaded.dueCount(DateTime(2026, 10, 31)), 1);

      await s.deleteLine('u1', rep.id, 'l2');
      await s.renameRepertoire('u1', rep.id, '四間飛車');
      final list = await s.repertoiresStream('u1').first;
      expect(list.single.name, '四間飛車');
      expect(list.single.lines.length, 1);

      await s.deleteRepertoire('u1', rep.id);
      expect(await s.repertoiresStream('u1').first, isEmpty);
    });
  });
}
