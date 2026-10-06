import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

void main() {
  final game = ShogiGame();

  test('lance handicap removes only 後手\'s left lance (row 0, col 0)', () {
    final standard = game.initialPosition();
    final handicapped = ShogiHandicapRule.lance.apply(standard);

    expect(handicapped.board[0][0], isNull);
    // Everything else is untouched.
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (r == 0 && c == 0) continue;
        expect(handicapped.board[r][c], standard.board[r][c]);
      }
    }
  });

  test('二枚落ち (rook-bishop) removes 後手\'s rook and bishop', () {
    final standard = game.initialPosition();
    final handicapped = ShogiHandicapRule.rookBishop.apply(standard);

    expect(handicapped.board[1][1], isNull);
    expect(handicapped.board[1][7], isNull);
  });

  test('八枚落ち removes all eight handicapped pieces', () {
    final standard = game.initialPosition();
    final handicapped = ShogiHandicapRule.eight.apply(standard);

    for (final (row, col) in ShogiHandicapRule.eight.removedSquares) {
      expect(handicapped.board[row][col], isNull);
    }
    // 下手 (Side.first) still moves first, same as a standard game.
    expect(handicapped.sideToMove, Side.first);
  });

  test('handicap does not mutate the standard initial position', () {
    final standard = game.initialPosition();
    ShogiHandicapRule.rook.apply(standard);
    expect(standard.board[1][1], isNotNull);
  });

  test('a handicapped position is still playable via legalMoves/apply', () {
    final handicapped = ShogiHandicapRule.rook.apply(game.initialPosition());
    final moves = game.legalMoves(handicapped);
    expect(moves, isNotEmpty);
    final after = game.apply(handicapped, moves.first);
    expect(after.sideToMove, Side.second);
  });
}
