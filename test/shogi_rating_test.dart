import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/utils/shogi_rating.dart';
import 'package:komovia_shogi/viewmodels/shogi_game_provider.dart';

void main() {
  group('opponentRatingForDifficulty', () {
    test('medium (the base level) maps to 1200 exactly', () {
      expect(opponentRatingForDifficulty(ShogiDifficulty.medium), 1200);
    });

    test('each difficulty step is 200 points apart', () {
      expect(opponentRatingForDifficulty(ShogiDifficulty.beginner), 800);
      expect(opponentRatingForDifficulty(ShogiDifficulty.easy), 1000);
      expect(opponentRatingForDifficulty(ShogiDifficulty.medium), 1200);
      expect(opponentRatingForDifficulty(ShogiDifficulty.hard), 1400);
    });
  });

  group('computeShogiRatingDelta', () {
    test('an ongoing result never changes the rating', () {
      final delta = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.medium,
        result: GameResult.ongoing,
        humanSide: Side.first,
      );
      expect(delta, 0);
    });

    test('beating the AI at an equal virtual rating gains points', () {
      final delta = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.medium,
        result: const GameResult.win(Side.first, WinReason.checkmate),
        humanSide: Side.first,
      );
      expect(delta, greaterThan(0));
    });

    test('losing to the AI loses points', () {
      final delta = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.medium,
        result: const GameResult.win(Side.second, WinReason.checkmate),
        humanSide: Side.first,
      );
      expect(delta, lessThan(0));
    });

    test('a draw at an equal virtual rating does not change the rating', () {
      final delta = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.medium,
        result: const GameResult.draw(WinReason.repetition),
        humanSide: Side.first,
      );
      expect(delta, 0);
    });

    test('beating a harder AI gains more than beating an easier one', () {
      final vsHard = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.hard,
        result: const GameResult.win(Side.first, WinReason.checkmate),
        humanSide: Side.first,
      );
      final vsBeginner = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.beginner,
        result: const GameResult.win(Side.first, WinReason.checkmate),
        humanSide: Side.first,
      );
      expect(vsHard, greaterThan(vsBeginner));
    });

    test('resignation (winner is the opponent) loses points like any loss',
        () {
      final delta = computeShogiRatingDelta(
        currentRating: 1200,
        difficulty: ShogiDifficulty.medium,
        result: const GameResult.win(Side.second, WinReason.resignation),
        humanSide: Side.first,
      );
      expect(delta, lessThan(0));
    });
  });
}
