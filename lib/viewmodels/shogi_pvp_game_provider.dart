import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/shogi_pvp_game.dart';
import '../services/shogi_pvp_game_service.dart';

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
