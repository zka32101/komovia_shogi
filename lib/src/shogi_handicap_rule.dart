import 'package:komovia_core/komovia_core.dart';

import 'piece.dart';
import 'shogi_position.dart';

/// Shogi's 駒落ち (piece-handicap) rules: remove one or more of 後手's
/// (the upper player's / 上手's) pieces from the standard initial
/// position. 下手 (Side.first) still moves first in every variant —
/// confirmed against `kouki-shogi`'s `game_screen.dart::_initBoard`,
/// which only ever removes pieces and never touches `sideToMove`.
///
/// The square set removed by each handicap is ported verbatim from
/// `_initBoard`'s `rmLeftLance`/`rmRightLance`/`rmKnight`/`rmSilver`/
/// `rmRook`/`rmBishop` membership sets (board is row-major,
/// `board[row][col]`, row 0 = 後手's back rank).
class ShogiHandicapRule implements HandicapRule<ShogiPosition> {
  @override
  final String id;

  @override
  final String label;

  final List<(int, int)> removedSquares;

  const ShogiHandicapRule._(this.id, this.label, this.removedSquares);

  static const lance = ShogiHandicapRule._('lance', '香落ち', [(0, 0)]);

  static const bishop = ShogiHandicapRule._('bishop', '角落ち', [(1, 7)]);

  static const rook = ShogiHandicapRule._('rook', '飛車落ち', [(1, 1)]);

  static const rookBishop = ShogiHandicapRule._(
    'rook-bishop',
    '飛角落ち',
    [(1, 1), (1, 7)],
  );

  static const four = ShogiHandicapRule._(
    'four',
    '四枚落ち',
    [(1, 1), (1, 7), (0, 0), (0, 8)],
  );

  static const six = ShogiHandicapRule._(
    'six',
    '六枚落ち',
    [(1, 1), (1, 7), (0, 0), (0, 8), (0, 1), (0, 7)],
  );

  static const eight = ShogiHandicapRule._(
    'eight',
    '八枚落ち',
    [(1, 1), (1, 7), (0, 0), (0, 8), (0, 1), (0, 7), (0, 2), (0, 6)],
  );

  /// Every non-平手 handicap, in increasing order of material removed.
  static const all = [lance, bishop, rook, rookBishop, four, six, eight];

  @override
  ShogiPosition apply(ShogiPosition standardInitialPosition) {
    final board = [
      for (final row in standardInitialPosition.board) List<Piece?>.of(row),
    ];
    for (final (row, col) in removedSquares) {
      board[row][col] = null;
    }
    return standardInitialPosition.copyWith(board: board);
  }
}
