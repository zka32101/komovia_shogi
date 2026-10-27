import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/active_shogi_game.dart';
import '../services/active_shogi_game_service.dart';
import 'auth_provider.dart';
import 'shogi_game_provider.dart';

/// 中断・再開機能。komovia_goの`game_provider.dart`にある
/// `activeAiGameProvider`/`resumeActiveGameProvider`/
/// `clearActiveAiGameProvider`と同じ役割を、将棋向けに分離したファイル
/// として持つ（shogi_game_provider.dartはあくまで対局そのものの状態、
/// こちらはその永続化・復元を担当）。
final activeShogiGameServiceProvider = Provider<ActiveShogiGameService>(
  (ref) => ActiveShogiGameService(),
);

/// 現在の対局状態をFirestoreへbest-effortで保存する。`main.dart`側の
/// 各対局操作（一手を指す・待った・新規対局開始）の直後に呼ぶ想定。
/// 失敗してもゲームプレイ自体をブロックしない — 未サインインなら
/// 保存先（uid）が無いのでそのまま何もしない。
final persistActiveShogiGameProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      final game = ref.read(shogiGameProvider);
      final kif = game.exportRecord(
        GameRecord(
          gameId: uid,
          moves: ref.read(shogiMoveHistoryProvider),
          result: ref.read(shogiResultProvider),
        ),
      );
      await ref
          .read(activeShogiGameServiceProvider)
          .save(
            ActiveShogiGame(
              uid: uid,
              difficultyName: ref.read(shogiDifficultyProvider).name,
              kifMoves: kif,
              quickGame: ref.read(shogiQuickGameProvider),
            ),
          );
    } catch (_) {
      // best-effort: 保存に失敗しても対局自体は続行できる
    }
  };
});

/// 対局が終局・投了した直後に呼ぶ。保存済みの進行中対局レコードを消し、
/// [isShogiGameActiveProvider]もfalseに戻す（終局した対局は「続きから」
/// の対象ではないため）。
final clearActiveShogiGameProvider = Provider<void Function()>((ref) {
  return () {
    ref.read(isShogiGameActiveProvider.notifier).state = false;
    () async {
      try {
        final uid = ref.read(currentUidProvider);
        if (uid == null) return;
        await ref.read(activeShogiGameServiceProvider).clear(uid);
      } catch (_) {
        // best-effort
      }
    }();
  };
});

/// 現在ログイン中のユーザーに進行中対局があるかどうか。HomeScreenが
/// 「続きから」カードを出すかどうかの判定に使う。
final activeShogiGameProvider = FutureProvider.autoDispose<ActiveShogiGame?>((
  ref,
) async {
  try {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return null;
    return await ref.read(activeShogiGameServiceProvider).getActive(uid);
  } catch (_) {
    return null;
  }
});

/// [activeShogiGameProvider]で取得した保存済みスナップショットから、
/// 対局状態プロバイダー群を復元する。[startShogiGameProvider]とは違い
/// 初期局面にリセットするのではなく、保存されていたKIF棋譜を初期局面
/// から打ち直して盤面・手数・棋譜・難易度・対局結果を復元する。
final resumeShogiGameProvider = Provider<void Function(ActiveShogiGame)>((
  ref,
) {
  return (saved) {
    final game = ref.read(shogiGameProvider);
    final record = game.importRecord(saved.kifMoves);

    var position = game.initialPosition();
    Move? lastMove;
    final historyKeys = <Object>[game.positionKey(position)];
    for (final recorded in record.moves) {
      position = game.apply(position, recorded.move);
      lastMove = recorded.move;
      if (recorded.move is! ResignMove) {
        historyKeys.add(game.positionKey(position));
      }
    }

    ref.read(shogiPositionProvider.notifier).state = position;
    ref.read(shogiLastMoveProvider.notifier).state = lastMove;
    ref.read(shogiMoveCountProvider.notifier).state = record.moves.length;
    ref.read(shogiMoveHistoryProvider.notifier).state = record.moves;
    ref.read(shogiPositionHistoryKeysProvider.notifier).state = historyKeys;
    ref.read(shogiResultProvider.notifier).state = record.result;
    ref.read(shogiDifficultyProvider.notifier).state = ShogiDifficulty.values
        .firstWhere(
          (d) => d.name == saved.difficultyName,
          orElse: () => ShogiDifficulty.medium,
        );
    ref.read(shogiQuickGameProvider.notifier).state = saved.quickGame;
    ref.read(isShogiGameActiveProvider.notifier).state = true;
  };
});
