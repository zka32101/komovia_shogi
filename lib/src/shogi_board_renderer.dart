import 'package:flutter/widgets.dart';
import 'package:komovia_core/komovia_core.dart';

import 'mini_board_widget.dart';
import 'shogi_position.dart';

/// Shogi's `BoardRenderer<ShogiPosition, Widget>`, wrapping
/// `MiniBoardWidget` (and, inside it, `KomaPainter`) ported unchanged
/// from `zka32101/kouki-shogi`.
///
/// `MiniBoardWidget` already matches the shared contract closely — it has
/// its own concepts for last-move highlighting, candidate-move dots, and
/// a highlighted square — so [build] is mostly a translation from
/// `komovia_core`'s [Square]/[Move] into `MiniBoardWidget`'s `(row, col)`
/// tuples. It uses a plain colored background rather than
/// `kouki-shogi`'s wood-grain-textured `BoardPainter` (used directly in
/// `game_screen.dart`, not via `MiniBoardWidget`) — porting that richer
/// background, and an advantage-overlay (see `BoardPainter.advantageRatio`
/// and `Engine.evaluate`), is a follow-up matching the design doc's
/// §3-5 "洗練されたUI" direction, not required for board correctness.
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
    );
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
