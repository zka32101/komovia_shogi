import 'package:cloud_firestore/cloud_firestore.dart';

/// 感想戦（AI検討）の1日あたり無料利用回数の管理
/// （`users/{uid}/ai_review_quota/daily`）。
///
/// 日付はローカル日付の`yyyy-MM-dd`文字列で持ち、保存済みの日付と今日が
/// 異なれば回数を0から数え直す（＝日付が変わるとリセット）。
/// [TsumeRushService] と同じコンストラクタDIで`fake_cloud_firestore`から
/// テストできる。
class AiReviewQuotaService {
  AiReviewQuotaService(
      {FirebaseFirestore? firestore, DateTime Function()? clock})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  /// 無料での1日あたり上限回数。
  static const int dailyLimit = 3;

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  DocumentReference<Map<String, Object?>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('ai_review_quota')
      .doc('daily');

  static String dateKey(DateTime t) => '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  /// 今日すでに使った回数。
  Future<int> usedToday(String uid) async {
    final data = (await _doc(uid).get()).data() ?? const {};
    if (data['date'] != dateKey(_clock())) return 0;
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  /// 1回分を消費する。上限に達していれば消費せずfalseを返す。
  /// トランザクション内で読み書きするので、連打しても上限を超えない。
  Future<bool> tryConsume(String uid) {
    final ref = _doc(uid);
    final today = dateKey(_clock());
    return _firestore.runTransaction((tx) async {
      final data = (await tx.get(ref)).data() ?? const {};
      final used =
          data['date'] == today ? (data['count'] as num?)?.toInt() ?? 0 : 0;
      if (used >= dailyLimit) return false;
      tx.set(ref, {'date': today, 'count': used + 1});
      return true;
    });
  }
}
