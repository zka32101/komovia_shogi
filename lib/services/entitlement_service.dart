import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_entitlements.dart';

/// 購入権利の読み書き（`users/{uid}/entitlements/current`、本人のみ）。
/// 他サービスと同じコンストラクタDIで`fake_cloud_firestore`からテストできる。
class EntitlementService {
  EntitlementService({FirebaseFirestore? firestore, DateTime Function()? clock})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  DocumentReference<Map<String, Object?>> _doc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('entitlements')
      .doc('current');

  Future<UserEntitlements> get(String uid) async {
    final data = (await _doc(uid).get()).data();
    return data == null ? UserEntitlements.none : UserEntitlements.fromJson(data);
  }

  Stream<UserEntitlements> stream(String uid) => _doc(uid).snapshots().map(
        (d) => d.data() == null
            ? UserEntitlements.none
            : UserEntitlements.fromJson(d.data()!),
      );

  /// プレミアムを[length]だけ付与する。[skipIfAlreadyActive]は起動毎の
  /// 再配信（purchaseRecovery）で期限が延び続けるのを防ぐ — komovia_goの
  /// `_grantEntitlement`と同じ理由（サーバー側レシート検証が無いため、
  /// 本物の更新と古い購入の再配信を区別できない）。
  /// 付与したらtrue、スキップしたらfalse。
  Future<bool> grantPremium(
    String uid,
    Duration length, {
    bool skipIfAlreadyActive = false,
  }) async {
    final now = _clock();
    if (skipIfAlreadyActive && (await get(uid)).isPremiumActive(now)) {
      return false;
    }
    await _doc(uid).set({
      'premiumStartDate': now.toIso8601String(),
      'premiumEndDate': now.add(length).toIso8601String(),
    }, SetOptions(merge: true));
    return true;
  }
}
