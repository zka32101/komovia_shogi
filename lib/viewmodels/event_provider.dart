import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/event_config_service.dart';

final eventConfigServiceProvider =
    Provider<EventConfigService>((ref) => EventConfigService());

/// 現在時刻。テストで固定時刻に差し替えるためのプロバイダー。
final eventClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

EventWindow? _activeOrNull(Ref ref, EventWindow? window) {
  if (window == null) return null;
  return window.isActive(ref.watch(eventClockProvider)()) ? window : null;
}

/// 「番外編：チェスを指す」の開催期間。開催中ならその [EventWindow]、
/// 未設定・期間外ならnull（=ホーム画面のタイルを非表示）。
final noveltyChessEventProvider = Provider<EventWindow?>((ref) => _activeOrNull(
    ref, ref.watch(eventConfigServiceProvider).noveltyChessWindow));

/// 「将棋駒 vs チェス駒」の開催期間。意味は [noveltyChessEventProvider] と同じ。
final hybridBattleEventProvider = Provider<EventWindow?>((ref) => _activeOrNull(
    ref, ref.watch(eventConfigServiceProvider).hybridBattleWindow));
