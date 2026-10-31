import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../utils/shogi_rating.dart';
import 'auth_provider.dart';
import 'leaderboard_provider.dart';
import 'shogi_game_provider.dart';
import 'user_profile_provider.dart';

/// 対局終了時にレーティング・対局数・勝数を更新する（komovia_goの
/// `_updateAiGameRating`に相当）。失敗はbest-effortで握りつぶす —
/// ソーシャル機能はサインイン済みでなければ動かないが、対局自体は
/// サインインなしでも遊べるため、ここで例外を投げると対局終了処理
/// そのものをブロックしてしまう。
final updateShogiRatingAfterGameProvider =
    Provider<Future<void> Function(GameResult result)>((ref) {
  return (result) async {
    if (result.kind == ResultKind.ongoing) return;

    try {
      final uid = ref.read(currentUidProvider);
      if (uid == null) return;
      final service = ref.read(leaderboardServiceProvider);
      final difficulty = ref.read(shogiDifficultyProvider);
      final entry = await service.getEntry(uid);
      final currentRating = entry?.rating ?? 1200;
      final delta = computeShogiRatingDelta(
        currentRating: currentRating,
        difficulty: difficulty,
        result: result,
        humanSide: shogiHumanSide,
      );
      final won =
          result.kind == ResultKind.win && result.winner == shogiHumanSide;
      await service.incrementStats(
        uid: uid,
        displayName: entry?.displayName ?? 'Player ${uid.substring(0, 6)}',
        ratingDelta: delta,
        gamesDelta: 1,
        winsDelta: won ? 1 : 0,
      );
      // 実績フレームの解放状態はこのエントリーから導出しているので再計算させる。
      ref.invalidate(unlockedAvatarFrameIdsProvider(uid));
    } catch (_) {
      // best-effort: 対局自体は常に続行できる
    }
  };
});
