import 'package:komovia_core/komovia_core.dart';

/// 購入で得た権利（`users/{uid}/entitlements/current`）。
///
/// `users/{uid}`本体はフレンド表示名の解決のため全サインインユーザーに
/// 読めるので、購入状態はそこに置かず本人だけが読める別ドキュメントに分ける。
/// 期限日時のみを持ち、「有効か」は常に現在時刻と比べて導出する
/// （フラグを別に持つと期限切れ後もtrueのまま残る事故が起こるため）。
class UserEntitlements {
  const UserEntitlements({this.premiumStartDate, this.premiumEndDate});

  static const UserEntitlements none = UserEntitlements();

  final DateTime? premiumStartDate;
  final DateTime? premiumEndDate;

  bool isPremiumActive(DateTime now) =>
      premiumEndDate != null && premiumEndDate!.isAfter(now);

  /// komovia_coreの共通[Entitlement]形式へ変換する（komovia_goの
  /// `UserEntitlement.toEntitlement`と同じ役割）。プラン種別は保存して
  /// いないのでplanは常にnull。
  Entitlement toEntitlement(DateTime now) => Entitlement(
        isActive: isPremiumActive(now),
        startedAt: premiumStartDate,
        expiresAt: premiumEndDate,
      );

  Map<String, Object?> toJson() => {
        'premiumStartDate': premiumStartDate?.toIso8601String(),
        'premiumEndDate': premiumEndDate?.toIso8601String(),
      };

  factory UserEntitlements.fromJson(Map<String, Object?> json) {
    DateTime? parse(Object? v) =>
        v is String ? DateTime.tryParse(v) : null;
    return UserEntitlements(
      premiumStartDate: parse(json['premiumStartDate']),
      premiumEndDate: parse(json['premiumEndDate']),
    );
  }
}
