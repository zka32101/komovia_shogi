import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/logic.dart';
import 'package:komovia_shogi/src/piece.dart';
import 'package:komovia_shogi/src/tsume/tsume_logic.dart';
import 'package:komovia_shogi/src/tsume/tsume_problems.dart';

/// 内蔵詰将棋の正しさを、エンジンの合法手生成・終局判定で機械検証する。
void main() {
  final game = ShogiGame();
  final puzzles = builtInTsumeProblems();

  test('a reasonable first-version set with unique ids', () {
    expect(puzzles.length, greaterThanOrEqualTo(20));
    expect(puzzles.map((p) => p.id).toSet(), hasLength(puzzles.length));
  });

  for (final puzzle in puzzles) {
    test('${puzzle.id} (${puzzle.title}) is a correct mate-in-1', () {
      final pos = puzzle.position;
      expect(pos.sideToMove, Side.first);
      expect(game.result(pos).isOngoing, isTrue);

      // 後手玉がちょうど1枚あり、出題時点で王手されていない
      final kings = [
        for (final row in pos.board)
          for (final p in row)
            if (p != null && !p.isPlayer1 && p.type == PieceType.king) p,
      ];
      expect(kings, hasLength(1));
      expect(GL.inCheck(pos.board, false), isFalse);

      expect(puzzle.solution, hasLength(1));
      final move = puzzle.solution.single;
      expect(game.legalMoves(pos), contains(move));
      final result = game.result(game.apply(pos, move));
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.checkmate);
      expect(TsumeJudge.isMatingMove(pos, move), isTrue);

      // 詰まない手は不正解と判定される（判定の健全性）
      final nonMates = game
          .legalMoves(pos)
          .where((m) => game.result(game.apply(pos, m)).isOngoing)
          .toList();
      expect(nonMates, isNotEmpty);
      for (final m in nonMates) {
        expect(TsumeJudge.isMatingMove(pos, m), isFalse);
      }
    });
  }
}
