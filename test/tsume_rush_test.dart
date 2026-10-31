import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/services/tsume_rush_service.dart';
import 'package:komovia_shogi/src/tsume/tsume_logic.dart';
import 'package:komovia_shogi/src/tsume/tsume_problems.dart';

const _wrong = BoardMove(from: Square(0, 8), to: Square(0, 7)); // 9i玉の前進

void main() {
  final puzzles = builtInTsumeProblems();

  group('TsumeJudge', () {
    test('rejects illegal moves', () {
      final p = puzzles.first;
      expect(
          TsumeJudge.isMatingMove(
              p.position, const DropMove(pieceType: 'rook', to: Square(0, 0))),
          isFalse);
    });

    test('accepts an alternative mate (rook drop puzzle has several)', () {
      final p = puzzles.firstWhere((p) => p.id == 'tsume-1te-5');
      expect(
          TsumeJudge.isMatingMove(
              p.position, const DropMove(pieceType: 'rook', to: Square(4, 0))),
          isTrue);
    });
  });

  group('TsumeRushSession', () {
    test('correct answers score and build a streak', () {
      final s = TsumeRushSession(puzzles: puzzles, random: Random(1));
      s.submit(s.current!.solution.single);
      s.submit(s.current!.solution.single);
      expect(s.score, 2);
      expect(s.streak, 2);
      expect(s.bestStreak, 2);
      expect(s.lives, 3);
      expect(s.isFinished, isFalse);
    });

    test('a wrong answer costs a life, resets the streak, and advances', () {
      final s = TsumeRushSession(puzzles: puzzles, random: Random(1));
      s.submit(s.current!.solution.single);
      final before = s.current;
      expect(s.submit(_wrong), TsumeAnswer.wrong);
      expect(s.current, isNot(same(before)));
      expect(s.lives, 2);
      expect(s.streak, 0);
      expect(s.bestStreak, 1);
    });

    test('ends after three mistakes', () {
      final s = TsumeRushSession(puzzles: puzzles, random: Random(1));
      for (var i = 0; i < 3; i++) {
        s.submit(_wrong);
      }
      expect(s.endReason, TsumeRushEndReason.outOfLives);
      expect(s.current, isNull);
      expect(() => s.submit(_wrong), throwsStateError);
    });

    test('ends when every puzzle has been played', () {
      final s = TsumeRushSession(puzzles: puzzles.take(2).toList());
      s.submit(s.current!.solution.single);
      s.submit(s.current!.solution.single);
      expect(s.endReason, TsumeRushEndReason.allSolved);
      expect(s.score, 2);
    });

    test('timeUp ends the run but does not override an earlier reason', () {
      final s = TsumeRushSession(puzzles: puzzles);
      s.timeUp();
      expect(s.endReason, TsumeRushEndReason.timeUp);
      final s2 = TsumeRushSession(puzzles: puzzles.take(1).toList());
      s2.submit(s2.current!.solution.single);
      s2.timeUp();
      expect(s2.endReason, TsumeRushEndReason.allSolved);
    });
  });

  group('TsumeRushService', () {
    test('keeps the max of best score / streak and counts runs', () async {
      final service = TsumeRushService(firestore: FakeFirebaseFirestore());
      var stats = await service.recordRun('u1', score: 5, bestStreak: 3);
      expect(stats.bestScore, 5);
      stats = await service.recordRun('u1', score: 2, bestStreak: 4);
      expect(stats.bestScore, 5);
      expect(stats.bestStreak, 4);
      expect(stats.runs, 2);
      final streamed = await service.statsStream('u1').first;
      expect(streamed.bestScore, 5);
      expect((await service.statsStream('other').first).runs, 0);
    });
  });
}
