import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/main.dart';
import 'package:komovia_shogi/src/piece.dart';
import 'package:komovia_shogi/viewmodels/index.dart';

/// Regression test for a real RenderFlex overflow found while building the
/// onboarding capture demo: `MiniBoardWidget` adds a 持ち駒 (hand) row
/// above/below the 9x9 grid whenever either side's hand is non-empty, but
/// both `ShogiGameScreen` (here) and the onboarding mini board used to wrap
/// it in a `SizedBox` with a fixed `height: boardSize` equal to its width —
/// which overflows the instant any hand becomes non-empty, i.e. after the
/// very first capture of any real game. Fixed by not forcing a height.
void main() {
  testWidgets(
      'the board does not overflow once a hand is non-empty (持ち駒 bar shown)',
      (tester) async {
    final game = ShogiGame();
    final position = game.initialPosition().copyWith(
          p1Hand: const {PieceType.pawn: 1},
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isShogiGameActiveProvider.overrideWith((ref) => true),
          shogiPositionProvider.overrideWith((ref) => position),
        ],
        child: const MaterialApp(home: ShogiGameScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'still does not overflow with both hands non-empty and multiple piece types',
      (tester) async {
    final game = ShogiGame();
    final position = game.initialPosition().copyWith(
          p1Hand: const {PieceType.pawn: 2, PieceType.silver: 1, PieceType.gold: 1},
          p2Hand: const {PieceType.bishop: 1, PieceType.knight: 1},
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isShogiGameActiveProvider.overrideWith((ref) => true),
          shogiPositionProvider.overrideWith((ref) => position),
        ],
        child: const MaterialApp(home: ShogiGameScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
