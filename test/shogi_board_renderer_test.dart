import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

void main() {
  final game = ShogiGame();
  final renderer = ShogiBoardRenderer();

  group('ShogiBoardRenderer.build', () {
    testWidgets('builds the initial position without throwing', (tester) async {
      final pos = game.initialPosition();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: renderer.build(pos),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds with a last move, hints, and a selected square',
        (tester) async {
      final pos = game.initialPosition();
      final move = game.legalMoves(pos).first;
      final after = game.apply(pos, move);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 360,
                child: renderer.build(
                  after,
                  lastMove: move,
                  hints: const [Square(4, 4)],
                  selected: const Square(0, 0),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ShogiBoardRenderer.squareAt', () {
    test('maps an offset inside the board to the right square', () {
      final pos = game.initialPosition();
      const boardSize = BoardSize(362, 362); // cellSize = (362-4)/9 = 39.78
      // Comfortably inside cell (file:0, rank:0): just past the border.
      final topLeft =
          renderer.squareAt(const BoardOffset(10, 10), boardSize, pos);
      expect(topLeft, const Square(0, 0));

      // Comfortably inside cell (file:8, rank:8), near the bottom-right.
      final bottomRight =
          renderer.squareAt(const BoardOffset(355, 355), boardSize, pos);
      expect(bottomRight, const Square(8, 8));
    });

    test('returns null outside the board', () {
      final pos = game.initialPosition();
      const boardSize = BoardSize(362, 362);
      expect(
        renderer.squareAt(const BoardOffset(-5, 10), boardSize, pos),
        isNull,
      );
      expect(
        renderer.squareAt(const BoardOffset(1000, 10), boardSize, pos),
        isNull,
      );
    });
  });
}
