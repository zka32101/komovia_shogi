import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/shogi_pvp_game.dart';
import '../services/game_invitation_service.dart';
import 'friend_provider.dart';
import 'notification_provider.dart';
import 'shogi_pvp_game_provider.dart';

final gameInvitationServiceProvider = Provider<GameInvitationService>(
  (ref) => GameInvitationService(friends: ref.watch(friendServiceProvider)),
);

/// [uid]宛ての保留中招待。購読開始時に期限切れ招待の掃除もbest-effortで行う。
final incomingGameInvitationsProvider =
    StreamProvider.family<List<GameInvitation>, String>((ref, uid) {
  final service = ref.watch(gameInvitationServiceProvider);
  service.cleanupExpiredInvitations(uid).ignore();
  return service.incomingStream(uid);
});

/// 招待を送り、相手へ`game_invitation`通知を送る（通知はbest-effort）。
/// ブロック等で送れなかった場合はnull。通知文言は画面側でローカライズして渡す。
final sendGameInvitationProvider = Provider<
    Future<GameInvitation?> Function({
      required String fromUid,
      required String fromDisplayName,
      required String toUid,
      required String toDisplayName,
      required String notificationTitle,
      required String notificationBody,
    })>((ref) {
  return ({
    required fromUid,
    required fromDisplayName,
    required toUid,
    required toDisplayName,
    required notificationTitle,
    required notificationBody,
  }) async {
    final invitation =
        await ref.read(gameInvitationServiceProvider).sendInvitation(
              fromUid: fromUid,
              fromDisplayName: fromDisplayName,
              toUid: toUid,
              toDisplayName: toDisplayName,
            );
    if (invitation == null) return null;
    try {
      await ref.read(notificationServiceProvider).send(
        uid: toUid,
        title: notificationTitle,
        body: notificationBody,
        type: 'game_invitation',
        data: {'invitationId': invitation.id},
      );
    } catch (_) {
      // best-effort: 招待自体は既に成立している
    }
    return invitation;
  };
});

/// 受信者[uid]が招待を承認し、PvP対局を作成する（招待した側が先手 —
/// マッチング画面の「申し込んだ側が先手」と同じ慣例）。既に処理済み・期限切れ
/// ならnull。対局作成は既存の[createShogiPvpGameProvider]を再利用する。
final acceptGameInvitationProvider =
    Provider<Future<ShogiPvpGame?> Function(String invitationId, String uid)>(
        (ref) {
  return (invitationId, uid) async {
    final invitation = await ref
        .read(gameInvitationServiceProvider)
        .acceptInvitation(invitationId: invitationId, uid: uid);
    if (invitation == null) return null;
    return ref.read(createShogiPvpGameProvider)(
      senteUid: invitation.fromUid,
      senteDisplayName: invitation.fromDisplayName,
      goteUid: invitation.toUid,
      goteDisplayName: invitation.toDisplayName,
    );
  };
});

final declineGameInvitationProvider =
    Provider<Future<bool> Function(String invitationId, String uid)>((ref) {
  return (invitationId, uid) => ref
      .read(gameInvitationServiceProvider)
      .declineInvitation(invitationId: invitationId, uid: uid);
});
