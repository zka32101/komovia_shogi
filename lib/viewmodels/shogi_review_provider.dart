import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import '../services/ai_review_quota_service.dart';
import 'auth_provider.dart';
import 'purchase_provider.dart';
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

final aiReviewQuotaServiceProvider = Provider<AiReviewQuotaService>(
  (ref) => AiReviewQuotaService(),
);

/// 感想戦を始めてよいかの判定結果。
enum AiReviewAccess {
  /// 実行してよい（無料枠を1回消費した、またはAI分析プラン加入中）。
  allowed,

  /// 本日の無料枠を使い切った（AI分析プランへの加入を案内する）。
  limitReached,

  /// uidが無く回数を記録できない（サインイン失敗・Firebase未初期化）。
  signInRequired,
}

/// 感想戦を1回分消費する。
///
/// - AI分析プラン加入中: 無料枠を消費せず無制限に許可。
/// - それ以外: 1日[AiReviewQuotaService.dailyLimit]回まで。
/// - uidが無い: 拒否（[AiReviewAccess.signInRequired]）。PR #45では
///   「記録できないので許可」していたが、それだと匿名サインインに
///   失敗した端末だけ無制限になってしまう。起動時に必ず匿名サインインする
///   ため通常は到達しないが、到達した場合は無料で使い放題にしない。
final consumeAiReviewQuotaProvider =
    Provider<Future<AiReviewAccess> Function()>((ref) {
  return () async {
    String? uid;
    try {
      uid = ref.read(currentUidProvider);
    } catch (_) {
      uid = null;
    }
    if (uid == null) return AiReviewAccess.signInRequired;
    final entitlements =
        await ref.read(entitlementServiceProvider).get(uid);
    if (entitlements.hasAiAnalysisPlan(DateTime.now())) {
      return AiReviewAccess.allowed;
    }
    final ok = await ref.read(aiReviewQuotaServiceProvider).tryConsume(uid);
    return ok ? AiReviewAccess.allowed : AiReviewAccess.limitReached;
  };
});
