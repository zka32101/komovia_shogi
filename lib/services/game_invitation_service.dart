import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import 'friend_service.dart';

/// フレンド間の対局招待（komovia_goの`GameInvitationService`と同じ役割）。
/// データの形と「応答できるか/取り消せるか/期限切れか」の判定は
/// komovia_coreの共有型[GameInvitation]を使い、ここではFirestoreの
/// 読み書き・二重承認防止のトランザクション・ブロック確認だけを行う。
/// 日時はcore型の`toJson`どおりISO8601文字列で保存する（期限の比較
/// クエリも同じ文字列形式で行う。ISO8601は辞書順=時刻順）。
class GameInvitationService {
  GameInvitationService({FirebaseFirestore? firestore, FriendService? friends})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _friends = friends ?? FriendService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final FriendService _friends;

  CollectionReference<Map<String, Object?>> get _invitations =>
      _firestore.collection('gameInvitations');

  /// 招待を送る。ブロック関係にある相手には送らずnullを返す
  /// （FriendService.blockFriendは両側にミラーするので送信者側の確認で足りる）。
  Future<GameInvitation?> sendInvitation({
    required String fromUid,
    required String fromDisplayName,
    required String toUid,
    required String toDisplayName,
    String? customMessage,
    DateTime? now,
  }) async {
    if (fromUid == toUid) return null;
    if (await _friends.isBlocked(fromUid, toUid)) return null;
    final createdAt = (now ?? DateTime.now()).toUtc();
    final doc = _invitations.doc();
    final invitation = GameInvitation(
      id: doc.id,
      fromUid: fromUid,
      fromDisplayName: fromDisplayName,
      toUid: toUid,
      toDisplayName: toDisplayName,
      customMessage: customMessage,
      createdAt: createdAt,
      expiresAt: createdAt.add(GameInvitation.defaultLifetime),
    );
    await doc.set(invitation.toJson());
    return invitation;
  }

  /// 受信者[uid]として承認する。まだ応答可能（保留中・期限内）な場合のみ
  /// トランザクション内でacceptedにして返す。二重タップ等で既に処理済みなら
  /// null — 承認が対局作成のトリガーなので、対局が2つ作られることはない。
  Future<GameInvitation?> acceptInvitation({
    required String invitationId,
    required String uid,
    DateTime? now,
  }) {
    return _respond(invitationId, uid, GameInvitationStatus.accepted, now);
  }

  Future<bool> declineInvitation({
    required String invitationId,
    required String uid,
    DateTime? now,
  }) async {
    final result = await _respond(
      invitationId,
      uid,
      GameInvitationStatus.declined,
      now,
    );
    return result != null;
  }

  Future<GameInvitation?> _respond(
    String invitationId,
    String uid,
    String newStatus,
    DateTime? now,
  ) {
    return _firestore.runTransaction<GameInvitation?>((tx) async {
      final ref = _invitations.doc(invitationId);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return null;
      final invitation = GameInvitation.fromJson({...data, 'id': snap.id});
      if (!invitation.canBeRespondedToBy(uid, now: now)) return null;
      tx.update(ref, {'status': newStatus});
      return invitation.copyWith(status: newStatus);
    });
  }

  /// 送信者が保留中の招待を取り消す（ドキュメントを削除）。
  Future<bool> cancelInvitation({
    required String invitationId,
    required String uid,
  }) async {
    final ref = _invitations.doc(invitationId);
    final snap = await ref.get();
    final data = snap.data();
    if (data == null) return false;
    final invitation = GameInvitation.fromJson({...data, 'id': snap.id});
    if (!invitation.canBeCancelledBy(uid)) return false;
    await ref.delete();
    return true;
  }

  /// [uid]宛ての保留中・期限内の招待（期限の近い順）。
  Stream<List<GameInvitation>> incomingStream(String uid, {DateTime? now}) {
    final nowIso = (now ?? DateTime.now()).toUtc().toIso8601String();
    return _invitations
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: GameInvitationStatus.pending)
        .where('expiresAt', isGreaterThan: nowIso)
        .orderBy('expiresAt')
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => GameInvitation.fromJson({...d.data(), 'id': d.id}))
              .toList(),
        );
  }

  /// [uid]が送った/受け取った、期限切れのまま保留中の招待を削除する
  /// （サーバー側スケジューラが無いため、読み込み時にbest-effortで呼ぶ）。
  Future<int> cleanupExpiredInvitations(String uid, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    var deleted = 0;
    for (final field in ['fromUid', 'toUid']) {
      try {
        final snap = await _invitations
            .where(field, isEqualTo: uid)
            .where('status', isEqualTo: GameInvitationStatus.pending)
            .where('expiresAt',
                isLessThanOrEqualTo: at.toUtc().toIso8601String())
            .get();
        for (final doc in snap.docs) {
          final inv = GameInvitation.fromJson({...doc.data(), 'id': doc.id});
          if (!inv.isStale(now: at)) continue;
          try {
            await doc.reference.delete();
            deleted++;
          } catch (_) {}
        }
      } catch (_) {}
    }
    return deleted;
  }
}
