import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// 感想戦（AI検討）の1日あたり無料利用回数の管理
/// （`users/{uid}/ai_review_quota/daily`）。
///
/// 「その日の回数か／日付が変わったか（ローカル日付で深夜リセット）」の
/// 判定はkomovia_coreの[DailyQuota]に委譲し、このクラスはFirestoreへの
/// 読み書きだけを担う。AI分析プラン加入者の無制限化は呼び出し側
/// （`consumeAiReviewQuotaProvider`）の責務。
///
/// 保存形式: `{date: ISO8601文字列, count: int}`。PR #45時点の
/// `yyyy-MM-dd`形式の日付も`DateTime.tryParse`でその日の0時として読める
/// ため、既存データはそのまま引き継がれる。
class AiReviewQuotaService {
  AiReviewQuotaService(
      {FirebaseFirestore? firestore, DateTime Function()? clock})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  /// 無料での1日あたり上限回数。
  static const int dailyLimit = 3;
  static const DailyQuota quota = DailyQuota(limit: dailyLimit);

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  DocumentReference<Map<String, Object?>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('ai_review_quota')
      .doc('daily');

  static ({int count, DateTime? date}) _stored(Map<String, Object?> data) => (
        count: (data['count'] as num?)?.toInt() ?? 0,
        date: data['date'] is String
            ? DateTime.tryParse(data['date'] as String)
            : null,
      );

  /// 今日すでに使った回数。
  Future<int> usedToday(String uid) async {
    final s = _stored((await _doc(uid).get()).data() ?? const {});
    return quota.usedToday(
        storedCount: s.count, storedDate: s.date, now: _clock());
  }

  /// 1回分を消費する。上限に達していれば消費せずfalseを返す。
  /// トランザクション内で読み書きするので、連打しても上限を超えない。
  Future<bool> tryConsume(String uid) {
    final ref = _doc(uid);
    final now = _clock();
    return _firestore.runTransaction((tx) async {
      final s = _stored((await tx.get(ref)).data() ?? const {});
      if (!quota.canUse(storedCount: s.count, storedDate: s.date, now: now)) {
        return false;
      }
      final next =
          quota.recordUse(storedCount: s.count, storedDate: s.date, now: now);
      tx.set(ref, {'date': next.date.toIso8601String(), 'count': next.count});
      return true;
    });
  }
}
