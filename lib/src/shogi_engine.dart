import 'package:komovia_core/komovia_core.dart';

import 'logic.dart';
import 'piece.dart';
import 'shogi_position.dart';

/// Shogi's `Engine<ShogiPosition>`, wrapping `logic.dart`'s `AI` class
/// (ported unchanged from `zka32101/kouki-shogi`).
///
/// This wraps `AI`'s synchronous search directly rather than going
/// through `AiIsolate`'s `compute()`-based isolate wrapper: `AiIsolate`
/// depends on `package:flutter/foundation.dart`, which this adapter
/// avoids so its correctness can be verified with a plain `dart test`
/// sandbox (no Flutter SDK available in this environment). Running the
/// search off the UI thread via `AiIsolate`/`compute()` is a follow-up —
/// `Engine.bestMove`/`evaluate`/`findForcedWin` are already `Future`-based
/// so that change is purely internal.
class ShogiEngine implements Engine<ShogiPosition> {
  @override
  String get modelVersion => 'builtin';

  @override
  Future<Move?> bestMove(
    ShogiPosition position, {
    required int level,
    Duration? timeBudget,
  }) async {
    final isP1 = position.sideToMove == Side.first;
    final move = timeBudget != null
        ? AI.bestMoveTimed(
            position.board,
            position.p1Hand,
            position.p2Hand,
            isP1,
            budget: timeBudget,
          )
        : AI.bestMove(
            position.board,
            position.p1Hand,
            position.p2Hand,
            isP1,
            level,
          );
    return move == null ? null : _toMove(move);
  }

  @override
  Future<double> evaluate(ShogiPosition position) async {
    // ignorePersonality: true — an objective evaluation (先手視点) for a
    // shared advantage display, not search-time personality bias. See
    // logic.dart's own doc comment on AI.eval.
    return AI
        .eval(
          position.board,
          position.p1Hand,
          position.p2Hand,
          ignorePersonality: true,
        )
        .toDouble();
  }

  @override
  Future<Move?> findForcedWin(
    ShogiPosition position, {
    required int maxPly,
  }) async {
    final isP1 = position.sideToMove == Side.first;
    final move = AI.findMate(
      position.board,
      position.p1Hand,
      position.p2Hand,
      isP1,
      maxDepth: maxPly,
    );
    return move == null ? null : _toMove(move);
  }

  static Move _toMove(AMove move) {
    if (move.drop != null) {
      return DropMove(pieceType: move.drop!.name, to: Square(move.tc, move.tr));
    }
    return BoardMove(
      from: Square(move.fc, move.fr),
      to: Square(move.tc, move.tr),
      promote: move.promote,
    );
  }
}
