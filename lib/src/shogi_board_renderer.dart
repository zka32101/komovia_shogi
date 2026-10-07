import 'package:flutter/widgets.dart';
import 'package:komovia_core/komovia_core.dart';

import 'mini_board_widget.dart';
import 'piece.dart';
import 'shogi_position.dart';

/// Shogi's `BoardRenderer<ShogiPosition, Widget>`, wrapping
/// `MiniBoardWidget` (and, inside it, `KomaPainter`) ported unchanged
/// from `zka32101/kouki-shogi`.
///
/// `MiniBoardWidget` already matches the shared contract closely — it has
/// its own concepts for last-move highlighting, candidate-move dots, and
/// a highlighted square — so [build] is mostly a translation from
/// `komovia_core`'s [Square]/[Move] into `MiniBoardWidget`'s `(row, col)`
/// tuples.
///
/// [textured] and [advantageRatio] are additional optional parameters
/// beyond the shared `BoardRenderer` contract (game-specific UI polish,
/// not part of the cross-game interface): the wood-grain background and
/// material-advantage overlay from `kouki-shogi`'s `BoardPainter`, per
/// the design doc's §3-5 "洗練されたUI" direction. See
/// [materialAdvantageRatio] for computing the latter.
///
/// [squareAt] assumes `showLabels: false` (as [build] renders), so the
/// whole given [BoardSize] is the 9x9 grid itself — matching
/// `MiniBoardWidget`'s own `cellSize = (boardSize - 4) / 9` (a 2px border
/// on each side).
class ShogiBoardRenderer implements BoardRenderer<ShogiPosition, Widget> {
  @override
  Widget build(
    ShogiPosition position, {
    Move? lastMove,
    List<Square> hints = const [],
    Square? selected,
    bool textured = false,
    double? advantageRatio,
  }) {
    (int, int)? lastFrom;
    (int, int)? lastTo;
    switch (lastMove) {
      case BoardMove(from: final from, to: final to):
        lastFrom = (from.rank, from.file);
        lastTo = (to.rank, to.file);
      case DropMove(to: final to):
        lastTo = (to.rank, to.file);
      case PassMove():
      case ResignMove():
      case null:
        break;
    }

    return MiniBoardWidget(
      board: position.board,
      moveDots: {for (final s in hints) (s.rank, s.file)},
      lastMoveFrom: lastFrom,
      lastMoveTo: lastTo,
      highlightSquares:
          selected == null ? const {} : {(selected.rank, selected.file)},
      showLabels: false,
      currentIsP1: position.sideToMove == Side.first,
      p1Hand: position.p1Hand,
      p2Hand: position.p2Hand,
      textured: textured,
      advantageRatio: advantageRatio,
    );
  }

  /// 先手's share of total piece value on the board and in hand (0.5 =
  /// even), for use as [build]'s `advantageRatio`. Ported from
  /// `game_screen.dart`'s `_advantageRatio()`: a simple material count,
  /// independent of `Engine.evaluate` (which is a full search
  /// evaluation) — the UI historically used this cheaper heuristic for
  /// its live overlay rather than re-running the engine on every ply.
  static double materialAdvantageRatio(ShogiPosition position) {
    const values = {
      PieceType.king: 0,
      PieceType.rook: 5,
      PieceType.bishop: 3,
      PieceType.gold: 1,
      PieceType.silver: 1,
      PieceType.knight: 1,
      PieceType.lance: 1,
      PieceType.pawn: 1,
      PieceType.promotedRook: 6,
      PieceType.promotedBishop: 4,
    };
    var p1Score = 0, p2Score = 0;
    for (final row in position.board) {
      for (final piece in row) {
        if (piece == null) continue;
        final value = values[piece.type] ?? 0;
        if (piece.isPlayer1) {
          p1Score += value;
        } else {
          p2Score += value;
        }
      }
    }
    position.p1Hand.forEach((type, count) => p1Score += (values[type] ?? 0) * count);
    position.p2Hand.forEach((type, count) => p2Score += (values[type] ?? 0) * count);
    final total = p1Score + p2Score;
    return total == 0 ? 0.5 : p1Score / total;
  }

  @override
  Square? squareAt(BoardOffset offset, BoardSize size, ShogiPosition position) {
    final boardSize = size.width;
    final cellSize = (boardSize - 4) / 9;
    if (cellSize <= 0) return null;
    final file = ((offset.dx - 2) / cellSize).floor();
    final rank = ((offset.dy - 2) / cellSize).floor();
    if (file < 0 || file > 8 || rank < 0 || rank > 8) return null;
    return Square(file, rank);
  }
}
