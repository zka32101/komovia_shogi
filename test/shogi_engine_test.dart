import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/piece.dart';

void main() {
  final game = ShogiGame();
  final engine = ShogiEngine();

  group('ShogiEngine', () {
    test('modelVersion is a non-empty identifier', () {
      expect(engine.modelVersion, isNotEmpty);
    });

    test(
      'bestMove with a time budget returns a legal move from the start',
      () async {
        final pos = game.initialPosition();
        final move = await engine.bestMove(
          pos,
          level: 5,
          timeBudget: const Duration(milliseconds: 200),
        );
        expect(move, isNotNull);
        expect(game.legalMoves(pos), contains(move));
      },
    );

    test(
      'bestMove with level 0 (depth 0) still returns a legal move',
      () async {
        final pos = game.initialPosition();
        final move = await engine.bestMove(pos, level: 0);
        expect(move, isNotNull);
        expect(game.legalMoves(pos), contains(move));
      },
    );

    test('evaluate the initial position is close to balanced', () async {
      final pos = game.initialPosition();
      final score = await engine.evaluate(pos);
      // Standard shogi's start is close to even; this is a sanity bound,
      // not an exact value (the evaluation is a heuristic, not a fixed
      // constant).
      expect(score.abs(), lessThan(200));
    });

    test('findForcedWin finds a 1-ply mate when one exists', () async {
      // p2 king at (0,0). p1 rook at (3,1) covers (0,1) and (1,1) along
      // file 1. Dropping p1's lance at (4,0) checks along file 0 and
      // covers (1,0) too, in one move: mate in 1.
      final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      board[0][0] = const Piece(PieceType.king, false);
      board[3][1] = const Piece(PieceType.rook, true);
      board[8][4] = const Piece(PieceType.king, true);
      final pos = ShogiPosition(
        board: board,
        p1Hand: const {PieceType.lance: 1},
        p2Hand: const {},
        sideToMove: Side.first,
      );
      expect(game.result(pos).isOngoing, isTrue);

      final move = await engine.findForcedWin(pos, maxPly: 1);
      expect(move, isNotNull);
      expect(game.legalMoves(pos), contains(move));

      final after = game.apply(pos, move!);
      final result = game.result(after);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.checkmate);
    });

    test(
      'findForcedWin returns null when no mate exists within maxPly',
      () async {
        final pos = game.initialPosition();
        final move = await engine.findForcedWin(pos, maxPly: 1);
        expect(move, isNull);
      },
    );
  });
}
