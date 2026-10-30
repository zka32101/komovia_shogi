import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/attack_map_preference_service.dart';

final attackMapPreferenceServiceProvider =
    Provider<AttackMapPreferenceService>((ref) => AttackMapPreferenceService());

/// 駒の効き（利き）可視化トグルの現在値。`ProviderScope`はアプリ全体で
/// 単一（`main.dart`参照）なので、AI対局画面とPvP対局画面のどちらで
/// オン/オフを切り替えても他方に引き継がれる。初期値は`false`で、
/// [loadShowAttackMapPreferenceProvider]の読み込みが終わった時点で
/// 前回永続化された値に更新される（[onboardingServiceProvider]周りの
/// 「非同期読み込み→反映」と同じパターン）。
final showAttackMapProvider = StateProvider<bool>((ref) => false);

/// SharedPreferencesから保存済みの値を読み込み、[showAttackMapProvider]
/// へ反映する。各画面の`initState`で一度呼び出す想定。
final loadShowAttackMapPreferenceProvider =
    Provider<Future<void> Function()>((ref) {
  return () async {
    final enabled =
        await ref.read(attackMapPreferenceServiceProvider).isEnabled();
    ref.read(showAttackMapProvider.notifier).state = enabled;
  };
});

/// トグルを反転し、新しい値を永続化する。
final toggleShowAttackMapProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final next = !ref.read(showAttackMapProvider);
    ref.read(showAttackMapProvider.notifier).state = next;
    await ref.read(attackMapPreferenceServiceProvider).setEnabled(next);
  };
});
