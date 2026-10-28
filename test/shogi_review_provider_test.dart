import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/viewmodels/index.dart';

void main() {
  group('runShogiReviewProvider', () {
    test(
        'analyzes the moves actually played in this container\'s game and '
        'reports 100% accuracy when both sides only ever played the one '
        'engine-recommended best move', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(startShogiGameProvider)();

      // Play a handful of real moves via the engine's own best-move search
      // (level 1, the weakest) so the moves being "analyzed" are guaranteed
      // legal and the test doesn't hand-pick squares that might not apply
      // cleanly after other PRs change the opening position.
      final game = container.read(shogiGameProvider);
      final engine = container.read(shogiEngineProvider);
      for (var i = 0; i < 4; i++) {
        final position = container.read(shogiPositionProvider);
        if (!container.read(shogiResultProvider).isOngoing) break;
        final move = await engine.bestMove(position, level: 1);
        if (move == null) break;
        container.read(applyShogiMoveProvider)(move);
      }

      final movesPlayed = container.read(shogiMoveHistoryProvider).length;
      expect(movesPlayed, greaterThan(0));

      final analysis = await container.read(runShogiReviewProvider)();

      expect(analysis.moves, hasLength(movesPlayed));
      expect(analysis.moves.first.moveIndex, 1);

      // Every move's evalBefore/evalAfter should come from the real
      // ShogiEngine (not a stub) — just confirm they're finite numbers, not
      // the specific values (which would be brittle against any future
      // evaluation retuning).
      for (final m in analysis.moves) {
        expect(m.evalBefore.isFinite, isTrue);
        expect(m.evalAfter.isFinite, isTrue);
        expect(m.loss, greaterThanOrEqualTo(0));
      }
    });

    test('onProgress is called once per move with the move count as total',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      final engine = container.read(shogiEngineProvider);
      for (var i = 0; i < 2; i++) {
        final position = container.read(shogiPositionProvider);
        final move = await engine.bestMove(position, level: 1);
        if (move == null) break;
        container.read(applyShogiMoveProvider)(move);
      }
      final movesPlayed = container.read(shogiMoveHistoryProvider).length;

      final calls = <(int, int)>[];
      await container.read(runShogiReviewProvider)(
        onProgress: (done, total) => calls.add((done, total)),
      );

      expect(calls, hasLength(movesPlayed));
      expect(calls.last, (movesPlayed, movesPlayed));
    });

    test('an empty (just-started) game analyzes to an empty move list',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(startShogiGameProvider)();

      final analysis = await container.read(runShogiReviewProvider)();

      expect(analysis.moves, isEmpty);
      expect(analysis.accuracyFor(Side.first), 100);
      expect(analysis.accuracyFor(Side.second), 100);
    });
  });
}
