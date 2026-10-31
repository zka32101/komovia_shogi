import 'package:komovia_core/komovia_core.dart';

/// 購入で得た権利（`users/{uid}/entitlements/current`）。
///
/// `users/{uid}`本体はフレンド表示名の解決のため全サインインユーザーに
/// 読めるので、購入状態はそこに置かず本人だけが読める別ドキュメントに分ける。
/// 期限日時のみを持ち、「有効か」は常に現在時刻と比べて導出する
/// （フラグを別に持つと期限切れ後もtrueのまま残る事故が起こるため）。
class UserEntitlements {
  const UserEntitlements({
    this.premiumStartDate,
    this.premiumEndDate,
    this.aiAnalysisPlanEndDate,
  });

  static const UserEntitlements none = UserEntitlements();

  final DateTime? premiumStartDate;
  final DateTime? premiumEndDate;

  /// AI分析プラン（プレミアムとは別売り）の期限。
  final DateTime? aiAnalysisPlanEndDate;

  /// 期限判定はkomovia_coreの[Entitlement.isCurrentlyActive]に委譲する。
  bool isPremiumActive(DateTime now) =>
      toEntitlement(now).isCurrentlyActive(now: now);

  /// AI分析プランをkomovia_coreの[Entitlement]として表したもの。
  Entitlement get aiAnalysisEntitlement => Entitlement(
        isActive: aiAnalysisPlanEndDate != null,
        expiresAt: aiAnalysisPlanEndDate,
      );

  bool hasAiAnalysisPlan(DateTime now) =>
      aiAnalysisEntitlement.isCurrentlyActive(now: now);

  /// komovia_coreの共通[Entitlement]形式へ変換する（komovia_goの
  /// `UserEntitlement.toEntitlement`と同じ役割）。プラン種別は保存して
  /// いないのでplanは常にnull。
  Entitlement toEntitlement(DateTime now) => Entitlement(
        isActive: premiumEndDate != null,
        startedAt: premiumStartDate,
        expiresAt: premiumEndDate,
      );

  Map<String, Object?> toJson() => {
        'premiumStartDate': premiumStartDate?.toIso8601String(),
        'premiumEndDate': premiumEndDate?.toIso8601String(),
        'aiAnalysisPlanEndDate': aiAnalysisPlanEndDate?.toIso8601String(),
      };

  factory UserEntitlements.fromJson(Map<String, Object?> json) {
    DateTime? parse(Object? v) =>
        v is String ? DateTime.tryParse(v) : null;
    return UserEntitlements(
      premiumStartDate: parse(json['premiumStartDate']),
      premiumEndDate: parse(json['premiumEndDate']),
      aiAnalysisPlanEndDate: parse(json['aiAnalysisPlanEndDate']),
    );
  }
}
