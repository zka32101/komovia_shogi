import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/shogi_pvp_game.dart';
import '../services/shogi_pvp_game_service.dart';
import 'notification_provider.dart';

/// komovia_goの`pvp_game_provider.dart`と同じ役割（将棋向け）。
/// `ShogiPvpGameService`の薄いRiverpodラッパー — サービス層のテストは
/// `test/shogi_pvp_game_service_test.dart`で既に行っているので、ここでは
/// Providerの配線自体を一度だけ確認するテストのみ追加する。
final shogiPvpGameServiceProvider = Provider<ShogiPvpGameService>((ref) {
  return ShogiPvpGameService(FirebaseFirestore.instance);
});

/// 対局のリアルタイム盤面（両対局者共通で購読）。
final shogiPvpGameStreamProvider =
    StreamProvider.family<ShogiPvpGame, String>((ref, gameId) {
  return ref.watch(shogiPvpGameServiceProvider).watchGame(gameId);
});

/// (gameId, uid, move)を渡して着手する。拒否された場合はfalseを返す
/// （画面側は戻り値を見て「非合法手」等のフィードバックを出す）。
final applyShogiPvpMoveProvider =
    Provider<Future<bool> Function(String gameId, String uid, Move move)>((
  ref,
) {
  final service = ref.watch(shogiPvpGameServiceProvider);
  return (gameId, uid, move) {
    return service.applyMove(gameId: gameId, uid: uid, move: move);
  };
});

/// 投了する。
final resignShogiPvpGameProvider =
    Provider<Future<void> Function(String gameId, String uid)>((ref) {
  final service = ref.watch(shogiPvpGameServiceProvider);
  return (gameId, uid) {
    return service.resign(gameId: gameId, uid: uid);
  };
});

/// 放置による不戦勝を申請する。条件を満たさなければfalse。
final claimShogiPvpAbandonmentProvider =
    Provider<Future<bool> Function(String gameId, String uid)>((ref) {
  final service = ref.watch(shogiPvpGameServiceProvider);
  return (gameId, uid) {
    return service.claimAbandonmentForfeit(gameId: gameId, claimantUid: uid);
  };
});

/// 新しいPvP対局を作成する。
final createShogiPvpGameProvider = Provider<
    Future<ShogiPvpGame> Function({
      required String senteUid,
      required String senteDisplayName,
      required String goteUid,
      required String goteDisplayName,
      String? matchId,
    })>((ref) {
  final service = ref.watch(shogiPvpGameServiceProvider);
  return ({
    required senteUid,
    required senteDisplayName,
    required goteUid,
    required goteDisplayName,
    matchId,
  }) {
    return service.createGame(
      senteUid: senteUid,
      senteDisplayName: senteDisplayName,
      goteUid: goteUid,
      goteDisplayName: goteDisplayName,
      matchId: matchId,
    );
  };
});

/// [uid]の進行中PvP対局一覧（`ShogiPvpGamesListScreen`用）。
final userActiveShogiPvpGamesProvider =
    FutureProvider.family<List<ShogiPvpGame>, String>((ref, uid) {
  return ref.watch(shogiPvpGameServiceProvider).getActiveGamesFor(uid);
});

/// 終局した対局[previous]の再戦を[requesterUid]が申し込む。先後を入れ替えた
/// 新規対局を[createShogiPvpGameProvider]経由で作成し、相手へ
/// `pvp_challenge`通知を送る（best-effort）。komovia_goの
/// `rematchPvpGameProvider`/komovia_reversiaの
/// `rematchReversiaPvpGameProvider`と同じ役割。対局中の対局・対局者以外
/// からの申し込みはnullを返して拒否する。将棋のPvP対局は現状トーナメントと
/// 紐付かない（`tournamentId`フィールド自体が無い）ため、その判定は不要。
/// 通知文言は画面側でローカライズして渡す。
final rematchShogiPvpGameProvider = Provider<
    Future<ShogiPvpGame?> Function({
      required ShogiPvpGame previous,
      required String requesterUid,
      required String notificationTitle,
      required String notificationBody,
    })>((ref) {
  return ({
    required previous,
    required requesterUid,
    required notificationTitle,
    required notificationBody,
  }) async {
    if (!previous.isFinished) return null;
    if (previous.playerColorOf(requesterUid) == 0) return null;

    final game = await ref.read(createShogiPvpGameProvider)(
      senteUid: previous.goteUid,
      senteDisplayName: previous.goteDisplayName,
      goteUid: previous.senteUid,
      goteDisplayName: previous.senteDisplayName,
    );

    final opponentUid = requesterUid == previous.senteUid
        ? previous.goteUid
        : previous.senteUid;
    try {
      await ref.read(notificationServiceProvider).send(
            uid: opponentUid,
            title: notificationTitle,
            body: notificationBody,
            type: 'pvp_challenge',
            data: {'gameId': game.id},
          );
    } catch (_) {
      // best-effort: 通知に失敗しても再戦対局自体は成立している
    }
    return game;
  };
});
