import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/models/active_shogi_game.dart';
import 'package:komovia_shogi/src/shogi_game.dart';
import 'package:komovia_shogi/viewmodels/index.dart';

void main() {
  group('persistActiveShogiGameProvider / resumeShogiGameProvider', () {
    test(
        'exports the current move history as KIF and resumeShogiGameProvider '
        'replays it back to the same position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final game = container.read(shogiGameProvider);

      container.read(startShogiGameProvider)(
        difficulty: ShogiDifficulty.hard,
      );
      final move1 = game
          .legalMoves(container.read(shogiPositionProvider))
          .whereType<BoardMove>()
          .first;
      container.read(applyShogiMoveProvider)(move1);
      final afterOneMove = container.read(shogiPositionProvider);

      final kif = game.exportRecord(
        GameRecord(
          gameId: 'test',
          moves: container.read(shogiMoveHistoryProvider),
          result: container.read(shogiResultProvider),
        ),
      );

      // Simulate a fresh app start: a brand-new container with default
      // (unstarted) state, then resume from the saved snapshot.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh.read(resumeShogiGameProvider)(
        ActiveShogiGame(uid: 'u1', difficultyName: 'hard', kifMoves: kif),
      );

      expect(
        game.encode(fresh.read(shogiPositionProvider)),
        game.encode(afterOneMove),
      );
      expect(fresh.read(shogiMoveCountProvider), 1);
      expect(fresh.read(shogiMoveHistoryProvider), hasLength(1));
      expect(fresh.read(shogiResultProvider), GameResult.ongoing);
      expect(fresh.read(shogiDifficultyProvider), ShogiDifficulty.hard);
      expect(fresh.read(isShogiGameActiveProvider), isTrue);
      expect(fresh.read(shogiLastMoveProvider), move1);
    });

    test(
        'resuming an empty (just-started, no moves yet) snapshot restores '
        'the initial position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final game = container.read(shogiGameProvider);

      final kif = game.exportRecord(
        const GameRecord(gameId: 'test', moves: [], result: GameResult.ongoing),
      );

      container.read(resumeShogiGameProvider)(
        ActiveShogiGame(uid: 'u1', difficultyName: 'easy', kifMoves: kif),
      );

      expect(
        game.encode(container.read(shogiPositionProvider)),
        game.encode(game.initialPosition()),
      );
      expect(container.read(shogiMoveCountProvider), 0);
      expect(container.read(shogiLastMoveProvider), isNull);
      expect(container.read(shogiDifficultyProvider), ShogiDifficulty.easy);
    });

    test(
        'resuming with an unrecognized difficulty name falls back to medium',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final game = container.read(shogiGameProvider);
      final kif = game.exportRecord(
        const GameRecord(gameId: 'test', moves: [], result: GameResult.ongoing),
      );

      container.read(resumeShogiGameProvider)(
        ActiveShogiGame(
          uid: 'u1',
          difficultyName: 'not-a-real-difficulty',
          kifMoves: kif,
        ),
      );

      expect(container.read(shogiDifficultyProvider), ShogiDifficulty.medium);
    });
  });

  group('clearActiveShogiGameProvider', () {
    test('marks the game as no longer active', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();
      expect(container.read(isShogiGameActiveProvider), isTrue);

      container.read(clearActiveShogiGameProvider)();

      expect(container.read(isShogiGameActiveProvider), isFalse);
    });

    test('does not throw when nobody is signed in (Firebase unavailable)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(clearActiveShogiGameProvider)(),
        returnsNormally,
      );
    });
  });

  group('persistActiveShogiGameProvider without Firebase', () {
    test('never throws, even though no Firebase app is configured', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      await expectLater(
        container.read(persistActiveShogiGameProvider)(),
        completes,
      );
    });
  });
}
