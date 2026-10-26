import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/models/active_shogi_game.dart';
import 'package:komovia_shogi/viewmodels/index.dart';

void main() {
  group('ShogiDifficultyExt.quickTimeBudget', () {
    test('a stronger difficulty gets a longer time budget', () {
      expect(
        ShogiDifficulty.hard.quickTimeBudget >
            ShogiDifficulty.medium.quickTimeBudget,
        isTrue,
      );
      expect(
        ShogiDifficulty.medium.quickTimeBudget >
            ShogiDifficulty.easy.quickTimeBudget,
        isTrue,
      );
      expect(
        ShogiDifficulty.easy.quickTimeBudget >
            ShogiDifficulty.beginner.quickTimeBudget,
        isTrue,
      );
    });
  });

  group('shogiQuickGameProvider', () {
    test('defaults to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(shogiQuickGameProvider), isFalse);
    });

    test('resumeShogiGameProvider restores the saved quickGame flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final game = container.read(shogiGameProvider);
      final kif = game.exportRecord(
        const GameRecord(gameId: 'test', moves: [], result: GameResult.ongoing),
      );

      container.read(resumeShogiGameProvider)(
        ActiveShogiGame(
          uid: 'u1',
          difficultyName: 'medium',
          kifMoves: kif,
          quickGame: true,
        ),
      );

      expect(container.read(shogiQuickGameProvider), isTrue);
    });
  });
}
