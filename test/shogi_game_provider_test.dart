import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/src/shogi_game.dart';
import 'package:komovia_shogi/viewmodels/index.dart';

void main() {
  group('shogiGameProvider state', () {
    test('starts with no active game and the initial position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isShogiGameActiveProvider), isFalse);
      final game = ShogiGame();
      expect(
        game.encode(container.read(shogiPositionProvider)),
        game.encode(game.initialPosition()),
      );
      expect(container.read(shogiMoveCountProvider), 0);
      expect(container.read(shogiMoveHistoryProvider), isEmpty);
      expect(container.read(shogiResultProvider), GameResult.ongoing);
      expect(container.read(shogiLastMoveProvider), isNull);
    });

    test('startShogiGameProvider marks the game active and resets state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(shogiMoveCountProvider.notifier).state = 5;
      container.read(startShogiGameProvider)();

      expect(container.read(isShogiGameActiveProvider), isTrue);
      expect(container.read(shogiMoveCountProvider), 0);
      expect(container.read(shogiResultProvider), GameResult.ongoing);
    });

    test(
        'startShogiGameProvider with a difficulty argument changes '
        'shogiDifficultyProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(startShogiGameProvider)(
        difficulty: ShogiDifficulty.hard,
      );

      expect(container.read(shogiDifficultyProvider), ShogiDifficulty.hard);
    });

    test(
        'startShogiGameProvider without a difficulty argument keeps the '
        'previously selected one', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(shogiDifficultyProvider.notifier).state =
          ShogiDifficulty.easy;
      container.read(startShogiGameProvider)();

      expect(container.read(shogiDifficultyProvider), ShogiDifficulty.easy);
    });

    test(
        'applyShogiMoveProvider updates the position, last move, move '
        'count, and move history', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      final game = container.read(shogiGameProvider);
      final move = game
          .legalMoves(container.read(shogiPositionProvider))
          .whereType<BoardMove>()
          .first;

      container.read(applyShogiMoveProvider)(move);

      expect(container.read(shogiLastMoveProvider), move);
      expect(container.read(shogiMoveCountProvider), 1);
      expect(container.read(shogiMoveHistoryProvider), hasLength(1));
      expect(
        container.read(shogiMoveHistoryProvider).single.move,
        move,
      );
      expect(
        container.read(shogiMoveHistoryProvider).single.side,
        shogiHumanSide,
      );
    });

    test(
        'applyShogiMoveProvider with a ResignMove does not add a move-'
        'history entry, but still updates the result', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      container.read(applyShogiMoveProvider)(ResignMove(shogiHumanSide));

      expect(container.read(shogiMoveHistoryProvider), isEmpty);
      expect(container.read(shogiMoveCountProvider), 0);
      expect(container.read(shogiResultProvider).isOngoing, isFalse);
    });

    test(
        'startShogiGameProvider seeds shogiPositionHistoryKeysProvider with '
        'the initial position; applyShogiMoveProvider grows it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      final game = container.read(shogiGameProvider);
      expect(container.read(shogiPositionHistoryKeysProvider), [
        game.positionKey(game.initialPosition()),
      ]);

      final move = game
          .legalMoves(container.read(shogiPositionProvider))
          .whereType<BoardMove>()
          .first;
      container.read(applyShogiMoveProvider)(move);

      expect(container.read(shogiPositionHistoryKeysProvider), hasLength(2));
      expect(
        container.read(shogiPositionHistoryKeysProvider).last,
        game.positionKey(container.read(shogiPositionProvider)),
      );
    });

    test(
        'a position repeated a fourth time is detected as 千日手 (repetition) '
        'via applyShogiMoveProvider, not just ShogiGame.result in isolation',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      // Shuffle both sides' 金 back and forth — a fully reversible cycle
      // that returns to the exact starting position (same side to move)
      // every 4 plies, with no capture to disturb hand counts.
      const p1Forward = BoardMove(from: Square(3, 8), to: Square(3, 7));
      const p1Back = BoardMove(from: Square(3, 7), to: Square(3, 8));
      const p2Forward = BoardMove(from: Square(3, 0), to: Square(3, 1));
      const p2Back = BoardMove(from: Square(3, 1), to: Square(3, 0));

      // The initial position is occurrence #1. Each full cycle below
      // returns to it again: 3 cycles => occurrences #2, #3, #4, and the
      // 4th occurrence is where fourfold repetition is actually detected.
      for (var cycle = 0; cycle < 3; cycle++) {
        container.read(applyShogiMoveProvider)(p1Forward);
        expect(container.read(shogiResultProvider).isOngoing, isTrue);
        container.read(applyShogiMoveProvider)(p2Forward);
        expect(container.read(shogiResultProvider).isOngoing, isTrue);
        container.read(applyShogiMoveProvider)(p1Back);
        expect(container.read(shogiResultProvider).isOngoing, isTrue);
        container.read(applyShogiMoveProvider)(p2Back);
      }

      final result = container.read(shogiResultProvider);
      expect(result.isOngoing, isFalse);
      expect(result.kind, ResultKind.draw);
      expect(result.reason, WinReason.repetition);
    });
  });
}
