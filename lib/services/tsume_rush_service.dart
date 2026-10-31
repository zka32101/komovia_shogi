import 'package:cloud_firestore/cloud_firestore.dart';

/// 詰将棋ラッシュの自己ベスト。
class TsumeRushStats {
  const TsumeRushStats({
    this.bestScore = 0,
    this.bestStreak = 0,
    this.runs = 0,
  });

  final int bestScore;
  final int bestStreak;
  final int runs;

  factory TsumeRushStats.fromFirestore(Map<String, Object?> data) =>
      TsumeRushStats(
        bestScore: (data['bestScore'] as num?)?.toInt() ?? 0,
        bestStreak: (data['bestStreak'] as num?)?.toInt() ?? 0,
        runs: (data['runs'] as num?)?.toInt() ?? 0,
      );
}

/// 自己ベストの永続化（`users/{uid}/tsume_rush/stats`）。
/// [RepertoireService] と同じコンストラクタDIで `fake_cloud_firestore`
/// からテストできる。
class TsumeRushService {
  TsumeRushService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('tsume_rush')
      .doc('stats');

  Stream<TsumeRushStats> statsStream(String uid) => _doc(uid)
      .snapshots()
      .map((d) => TsumeRushStats.fromFirestore(d.data() ?? const {}));

  /// 1回分の結果を記録し、更新後の自己ベストを返す（トランザクションで
  /// 既存値との max を取るので、古い値で上書きしない）。
  Future<TsumeRushStats> recordRun(
    String uid, {
    required int score,
    required int bestStreak,
  }) {
    final ref = _doc(uid);
    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final prev = TsumeRushStats.fromFirestore(snap.data() ?? const {});
      final next = TsumeRushStats(
        bestScore: score > prev.bestScore ? score : prev.bestScore,
        bestStreak: bestStreak > prev.bestStreak ? bestStreak : prev.bestStreak,
        runs: prev.runs + 1,
      );
      tx.set(ref, {
        'bestScore': next.bestScore,
        'bestStreak': next.bestStreak,
        'runs': next.runs,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return next;
    });
  }
}
