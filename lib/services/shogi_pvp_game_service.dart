import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/shogi_pvp_game.dart';
import '../src/shogi_game.dart';
import '../src/shogi_position.dart';

/// PvP対局サービス - マッチング成立後の2人プレイヤー間対局。
/// komovia_goの`PvpGameService`と同じ役割だが、盤面はFirestoreへ直接
/// エンコードせず、`ShogiPvpGame.kifMoves`（KIF棋譜文字列）を都度
/// 初期局面から打ち直して再構成する（`ShogiPvpGame`のクラスコメント
/// 参照）。放置対局の救済は[claimAbandonmentForfeit]（判定ロジックは
/// komovia_coreの共有型`AbandonmentForfeitPolicy`）。持ち時間は未実装。
class ShogiPvpGameService {
  ShogiPvpGameService(this._firestore, {ShogiGame? game})
      : _game = game ?? ShogiGame();

  final FirebaseFirestore _firestore;
  final ShogiGame _game;

  /// 放置対局の不戦勝申請ポリシー。komovia_go/komovia_chessは48時間だが、
  /// 将棋は1局が数十〜百数十手と長く、相手の応手待ちで丸2日止まると
  /// 実質的に対局が終わってしまうため、24時間に短縮する（「1日1手は
  /// 指せる」程度の猶予は残し、時間に追われない設計方針とも両立させる）。
  static const AbandonmentForfeitPolicy abandonmentPolicy =
      AbandonmentForfeitPolicy(threshold: Duration(hours: 24));

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('shogi_pvp_games');

  Future<ShogiPvpGame> createGame({
    required String senteUid,
    required String senteDisplayName,
    required String goteUid,
    required String goteDisplayName,
    String? matchId,
  }) async {
    final docRef = _games.doc();
    final game = ShogiPvpGame(
      id: docRef.id,
      senteUid: senteUid,
      senteDisplayName: senteDisplayName,
      goteUid: goteUid,
      goteDisplayName: goteDisplayName,
      isSenteTurn: true,
      movesCount: 0,
      status: 'active',
      matchId: matchId,
      createdAt: DateTime.now(),
    );
    await docRef.set(game.toFirestore());
    return game;
  }

  Future<ShogiPvpGame?> getGame(String gameId) async {
    final doc = await _games.doc(gameId).get();
    if (!doc.exists) return null;
    return ShogiPvpGame.fromFirestore(doc);
  }

  Stream<ShogiPvpGame> watchGame(String gameId) =>
      _games.doc(gameId).snapshots().map(ShogiPvpGame.fromFirestore);

  /// [kifMoves]から現局面・局面履歴（千日手判定用）・着手リストを
  /// 初期局面から打ち直して再構成する。`resumeShogiGameProvider`
  /// （進行中AI対局の再開）と同じロジック。
  ({ShogiPosition position, List<Object> historyKeys, List<RecordedMove> moves})
      _replay(String kifMoves) {
    var position = _game.initialPosition();
    final historyKeys = <Object>[_game.positionKey(position)];
    final moves = <RecordedMove>[];
    if (kifMoves.isNotEmpty) {
      final record = _game.importRecord(kifMoves);
      for (final recorded in record.moves) {
        position = _game.apply(position, recorded.move);
        historyKeys.add(_game.positionKey(position));
        moves.add(recorded);
      }
    }
    return (position: position, historyKeys: historyKeys, moves: moves);
  }

  /// [move]を適用する。手番でない・非対局者・終局済み・非合法手の
  /// いずれかであれば何もせず`false`を返す（komovia_goの`applyMove`と
  /// 同じ「黙って拒否する」設計）。
  Future<bool> applyMove({
    required String gameId,
    required String uid,
    required Move move,
  }) {
    return _firestore.runTransaction<bool>((transaction) async {
      final docRef = _games.doc(gameId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      final pvp = ShogiPvpGame.fromFirestore(snapshot);
      if (!pvp.isActive || !pvp.isTurnOf(uid)) return false;

      final replay = _replay(pvp.kifMoves);
      final legal = _game.legalMoves(
        replay.position,
        historyKeys: replay.historyKeys,
      );
      if (!legal.contains(move)) return false;

      final side = replay.position.sideToMove;
      final newPosition = _game.apply(
        replay.position,
        move,
        historyKeys: replay.historyKeys,
      );
      final newHistoryKeys = [...replay.historyKeys, _game.positionKey(newPosition)];
      final newMoveNumber = replay.moves.length + 1;
      final newMoves = [
        ...replay.moves,
        RecordedMove(number: newMoveNumber, side: side, move: move),
      ];

      final result = _game.result(newPosition, historyKeys: newHistoryKeys);
      final newKif = _game.exportRecord(
        GameRecord(gameId: gameId, moves: newMoves, result: result),
      );

      final updates = <String, Object?>{
        'kifMoves': newKif,
        'isSenteTurn': newPosition.sideToMove == Side.first,
        'movesCount': newMoveNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!result.isOngoing) {
        updates['status'] = 'finished';
        if (result.kind == ResultKind.win) {
          updates['winnerUid'] =
              result.winner == Side.first ? pvp.senteUid : pvp.goteUid;
          updates['result'] = result.reason == WinReason.resignation
              ? 'resignation'
              : 'checkmate';
        } else {
          updates['result'] = 'draw';
        }
      }

      transaction.update(docRef, updates);
      return true;
    });
  }

  /// 投了する。非対局者・終局済みであれば何もしない。
  Future<void> resign({required String gameId, required String uid}) {
    return _firestore.runTransaction<void>((transaction) async {
      final docRef = _games.doc(gameId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final pvp = ShogiPvpGame.fromFirestore(snapshot);
      if (!pvp.isActive) return;

      final color = pvp.playerColorOf(uid);
      if (color == 0) return;
      final winnerUid = color == 1 ? pvp.goteUid : pvp.senteUid;

      transaction.update(docRef, {
        'status': 'finished',
        'winnerUid': winnerUid,
        'result': 'resignation',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 相手が[abandonmentPolicy]の閾値以上着手していない場合に、
  /// 手番を待っている側が不戦勝を申請する。トランザクション内で現在の
  /// 状態に対して条件を再確認するので、相手の着手・投了と同時に呼ばれても
  /// 結果が上書きされない。条件を満たさなければ何もせず`false`を返す。
  Future<bool> claimAbandonmentForfeit({
    required String gameId,
    required String claimantUid,
    DateTime? now,
  }) {
    return _firestore.runTransaction<bool>((transaction) async {
      final docRef = _games.doc(gameId);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return false;

      final pvp = ShogiPvpGame.fromFirestore(snapshot);
      if (!pvp.canClaimAbandonmentForfeit(
        claimantUid,
        policy: abandonmentPolicy,
        now: now,
      )) {
        return false;
      }

      transaction.update(docRef, {
        'status': 'finished',
        'winnerUid': claimantUid,
        'result': 'forfeit',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }
}
