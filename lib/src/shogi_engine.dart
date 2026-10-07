import 'package:flutter/foundation.dart';
import 'package:komovia_core/komovia_core.dart';

import 'ai_isolate_worker.dart';
import 'piece.dart';
import 'shogi_position.dart';

/// Shogi's `Engine<ShogiPosition>`, wrapping `logic.dart`'s `AI` class
/// (ported unchanged from `zka32101/kouki-shogi`).
///
/// Each search runs via `compute()` (in `ai_isolate_worker.dart`'s
/// top-level worker functions) so it doesn't block the UI thread —
/// matching `kouki-shogi`'s own `AiIsolate`, though that wrapper only
/// covered `bestMoveTimed`/`topMovesTimed`/`findMate`; the level-based
/// `bestMove` and `eval` workers here are new, needed because
/// `Engine.bestMove`/`evaluate` cover both. The board/hands are encoded
/// to flat int lists before crossing the isolate boundary, the same
/// encoding `AiIsolate` uses.
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
    final params = {
      ...positionParams(position.board, position.p1Hand, position.p2Hand, isP1),
      if (timeBudget != null) 'budgetMs': timeBudget.inMilliseconds,
      if (timeBudget == null) 'level': level,
    };
    final json = timeBudget != null
        ? await compute(bestMoveTimedWorker, params)
        : await compute(bestMoveLevelWorker, params);
    return json == null ? null : _toMove(AMove.fromJson(json));
  }

  @override
  Future<double> evaluate(ShogiPosition position) async {
    // ignorePersonality: true — an objective evaluation (先手視点) for a
    // shared advantage display, not search-time personality bias. See
    // logic.dart's own doc comment on AI.eval.
    final isP1 = position.sideToMove == Side.first;
    return compute(
      evaluateWorker,
      positionParams(position.board, position.p1Hand, position.p2Hand, isP1),
    );
  }

  @override
  Future<Move?> findForcedWin(
    ShogiPosition position, {
    required int maxPly,
  }) async {
    final isP1 = position.sideToMove == Side.first;
    final params = {
      ...positionParams(position.board, position.p1Hand, position.p2Hand, isP1),
      'maxDepth': maxPly,
    };
    final json = await compute(findMateWorker, params);
    return json == null ? null : _toMove(AMove.fromJson(json));
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
