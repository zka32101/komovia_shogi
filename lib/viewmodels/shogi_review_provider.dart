import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import 'auth_provider.dart';
import 'shogi_game_provider.dart';

/// komovia_core PR #7で追加された共有`EngineReviewEngine`を、既存の
/// `shogiGameProvider`/`shogiEngineProvider`（どちらもすでに存在する）
/// だけで組み立てる — 将棋専用の検討ロジックは一切書かない。
final shogiReviewEngineProvider = Provider<EngineReviewEngine<ShogiPosition>>((
  ref,
) {
  return EngineReviewEngine(
    game: ref.read(shogiGameProvider),
    engine: ref.read(shogiEngineProvider),
  );
});

/// 終局後の対局を検討する。`persistActiveShogiGameProvider`と同じ
/// 「GameRecordをその場で組み立てる」パターン — 対局の初期局面は常に
/// 標準局面（ShogiGame.initialPosition()）なので、保存済みの初期局面を
/// 別途持つ必要が無い。
///
/// 評価は1手ごとにエンジンを呼ぶため数秒かかりうる — `onProgress`は
/// （消化済み, 全手数）を都度通知する。
final runShogiReviewProvider =
    Provider<
      Future<GameAnalysis> Function({void Function(int, int)? onProgress})
    >((ref) {
      return ({onProgress}) {
        String uid;
        try {
          uid = ref.read(currentUidProvider) ?? 'local';
        } catch (_) {
          // Firebaseが未初期化（単体テストなど）でもGameRecord.gameId自体は
          // 検討結果に使わないため、ここで落とさず局所的なダミー値で続行する。
          uid = 'local';
        }
        final game = ref.read(shogiGameProvider);
        final record = GameRecord(
          gameId: uid,
          moves: ref.read(shogiMoveHistoryProvider),
          result: ref.read(shogiResultProvider),
        );
        return ref
            .read(shogiReviewEngineProvider)
            .analyzeGame(
              record,
              game.initialPosition(),
              onProgress: onProgress,
            );
      };
    });
