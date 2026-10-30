import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart' show MatchCandidate, findBestMatchCandidate;

import '../models/shogi_matching.dart';

/// 実力マッチングEngine。komovia_goの`MatchingService`と同じ設計
/// （候補選定はトランザクション外、成立の書き込みはトランザクション内で
/// 候補の状態を再確認してから行い、二重成立を防ぐ）だが、`boardSize`
/// フィルタは無い（将棋は一盤種のみ）。候補選定の中核ロジックは
/// komovia_coreの`findBestMatchCandidate`に委譲（go/shogi/reversiaで
/// 一字一句重複していたため抽出されたもの）。
class ShogiMatchingService {
  ShogiMatchingService(this._firestore);

  final FirebaseFirestore _firestore;

  /// マッチ判定の許容レート差。
  static const int maxRatingDiff = 200;

  Future<void> joinQueue({
    required String uid,
    required String displayName,
    required int rating,
  }) {
    return _firestore.collection('shogi_matchmaking_queue').doc(uid).set(
          ShogiMatchmakingQueueEntry(
            uid: uid,
            displayName: displayName,
            rating: rating,
            queuedAt: DateTime.now(),
            status: 'waiting',
          ).toFirestore(),
        );
  }

  Future<void> leaveQueue(String uid) {
    return _firestore.collection('shogi_matchmaking_queue').doc(uid).delete();
  }

  /// レート差が最も近い待機中プレイヤーを探し、マッチが見つかれば成立させる。
  ///
  /// 候補者選定（誰が一番近いか）はコレクションクエリが必要なため
  /// トランザクション外で行うが、実際にマッチを成立させる書き込みは
  /// トランザクション内で候補者の状態を再確認してから行う。これにより、
  /// 2人のユーザーがほぼ同時に同じ候補者を見つけても、片方だけが
  /// マッチを成立させ、もう片方は「見つからなかった」扱いになる。
  Future<ShogiMatchResult?> findMatch({
    required String uid,
    required String displayName,
    required int rating,
  }) async {
    final snapshots = await _firestore
        .collection('shogi_matchmaking_queue')
        .where('status', isEqualTo: 'waiting')
        .get();

    final entries = {
      for (final doc in snapshots.docs) doc.id: ShogiMatchmakingQueueEntry.fromFirestore(doc),
    };

    final bestCandidate = findBestMatchCandidate(
      selfUid: uid,
      selfRating: rating,
      maxRatingDiff: maxRatingDiff,
      candidates: entries.values
          .map((entry) => MatchCandidate(uid: entry.uid, rating: entry.rating)),
    );

    if (bestCandidate == null) return null;

    final selectedCandidate = entries[bestCandidate.uid]!;
    final selectedDiff = (selectedCandidate.rating - rating).abs();
    final selfRef = _firestore.collection('shogi_matchmaking_queue').doc(uid);
    final candidateRef =
        _firestore.collection('shogi_matchmaking_queue').doc(selectedCandidate.uid);
    final matchRef = _firestore.collection('shogi_match_results').doc();

    return _firestore.runTransaction<ShogiMatchResult?>((transaction) async {
      final selfDoc = await transaction.get(selfRef);
      final candidateDoc = await transaction.get(candidateRef);
      final selfStatus = selfDoc.data()?['status'] as String?;
      final candidateStatus = candidateDoc.data()?['status'] as String?;

      if (selfStatus != 'waiting' || candidateStatus != 'waiting') {
        return null;
      }

      final result = ShogiMatchResult(
        id: matchRef.id,
        player1Uid: uid,
        player1DisplayName: displayName,
        player1Rating: rating,
        player2Uid: selectedCandidate.uid,
        player2DisplayName: selectedCandidate.displayName,
        player2Rating: selectedCandidate.rating,
        ratingDiff: selectedDiff,
        createdAt: DateTime.now(),
      );

      transaction.set(matchRef, result.toFirestore());
      transaction.update(selfRef, {'status': 'matched'});
      transaction.update(candidateRef, {'status': 'matched'});
      return result;
    });
  }

  Future<List<ShogiMatchResult>> getMatchHistory(String uid, {int limit = 50}) async {
    final p1Snapshots = await _firestore
        .collection('shogi_match_results')
        .where('player1Uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final p2Snapshots = await _firestore
        .collection('shogi_match_results')
        .where('player2Uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    final matches = [
      ...p1Snapshots.docs.map((doc) => ShogiMatchResult.fromFirestore(doc)),
      ...p2Snapshots.docs.map((doc) => ShogiMatchResult.fromFirestore(doc)),
    ];
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches.take(limit).toList();
  }

  Future<void> attachGameToMatch(String matchId, String gameId) {
    return _firestore.collection('shogi_match_results').doc(matchId).update({'gameId': gameId});
  }
}
