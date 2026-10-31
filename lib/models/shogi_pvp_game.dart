import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// 2人のプレイヤー間の対局（マッチング成立後の実対局）のスナップショット。
///
/// komovia_goの`PvpGame`と同じ役割だが、盤面そのものは保存しない —
/// `ActiveShogiGame`（進行中AI対局の中断・再開）と同じ設計判断で、
/// `ShogiGame.exportRecord`/`importRecord`が生成・解釈するKIF形式の
/// 棋譜文字列(`kifMoves`)だけを保存し、再構成時は初期局面から打ち直す。
/// 盤面を独自にFirestoreへエンコードする道を新たに増やさないことで、
/// 既にテスト済みのKIFラウンドトリップをそのまま流用している。
///
/// このPRではモデルのみを追加する（実際に着手を適用するサービス層は
/// komovia_goの`PvpGameService`と同等の、`ShogiGame`をFirestore
/// トランザクション内で実行するロジックが必要になり、別PRの範囲）。
class ShogiPvpGame {
  final String id;
  final String senteUid;
  final String senteDisplayName;
  final String goteUid;
  final String goteDisplayName;
  final String kifMoves;
  final bool isSenteTurn;
  final int movesCount;
  final String status; // 'active', 'finished'
  final String? winnerUid;
  final String? result; // 'resignation', 'checkmate', 'draw', 'forfeit'(放置による不戦勝), null(進行中)
  final String? matchId; // ShogiMatchResult.idとの紐付け（あれば）
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShogiPvpGame({
    required this.id,
    required this.senteUid,
    required this.senteDisplayName,
    required this.goteUid,
    required this.goteDisplayName,
    this.kifMoves = '',
    required this.isSenteTurn,
    required this.movesCount,
    required this.status,
    this.winnerUid,
    this.result,
    this.matchId,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  /// uidが先手なら1、後手なら2、対局者でなければ0。
  int playerColorOf(String uid) {
    if (uid == senteUid) return 1;
    if (uid == goteUid) return 2;
    return 0;
  }

  bool isTurnOf(String uid) {
    final color = playerColorOf(uid);
    if (color == 0) return false;
    return (color == 1) == isSenteTurn;
  }

  /// 最後に盤面が動いた時刻（未着手なら作成時刻）。
  DateTime get lastActivityAt => updatedAt ?? createdAt;

  /// [uid]が放置による不戦勝を申請できるか。対局中・対局者・相手の手番
  /// （＝[uid]は待っている側）であることを確認したうえで、時間判定は
  /// komovia_coreの[AbandonmentForfeitPolicy]に委ねる。
  bool canClaimAbandonmentForfeit(
    String uid, {
    required AbandonmentForfeitPolicy policy,
    DateTime? now,
  }) {
    if (!isActive || playerColorOf(uid) == 0) return false;
    return policy.canClaim(
      isClaimantsTurn: isTurnOf(uid),
      lastActivityAt: lastActivityAt,
      now: now,
    );
  }

  factory ShogiPvpGame.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ShogiPvpGame(
      id: doc.id,
      senteUid: data['senteUid'] as String? ?? '',
      senteDisplayName: data['senteDisplayName'] as String? ?? '先手',
      goteUid: data['goteUid'] as String? ?? '',
      goteDisplayName: data['goteDisplayName'] as String? ?? '後手',
      kifMoves: data['kifMoves'] as String? ?? '',
      isSenteTurn: data['isSenteTurn'] as bool? ?? true,
      movesCount: data['movesCount'] as int? ?? 0,
      status: data['status'] as String? ?? 'active',
      winnerUid: data['winnerUid'] as String?,
      result: data['result'] as String?,
      matchId: data['matchId'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senteUid': senteUid,
      'senteDisplayName': senteDisplayName,
      'goteUid': goteUid,
      'goteDisplayName': goteDisplayName,
      'kifMoves': kifMoves,
      'isSenteTurn': isSenteTurn,
      'movesCount': movesCount,
      'status': status,
      'winnerUid': winnerUid,
      'result': result,
      'matchId': matchId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}
