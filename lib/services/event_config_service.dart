import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:komovia_core/komovia_core.dart';

/// 期間限定イベント（番外編モード）の開催期間を Firebase Remote Config
/// から読み出すサービス。
///
/// 各イベントは開始/終了の ISO-8601 文字列キーの組で表し、どちらかが
/// 空・不正なら「イベント未設定」= 非表示（fail closed）。管理者が
/// Remote Config に期間を設定して初めて表示される。
class EventConfigService {
  EventConfigService({String Function(String key)? valueReader})
      : _valueReader = valueReader;

  static const noveltyChessStartKey = 'novelty_chess_event_start';
  static const noveltyChessEndKey = 'novelty_chess_event_end';
  static const hybridBattleStartKey = 'hybrid_battle_event_start';
  static const hybridBattleEndKey = 'hybrid_battle_event_end';

  static const Map<String, String> defaults = {
    noveltyChessStartKey: '',
    noveltyChessEndKey: '',
    hybridBattleStartKey: '',
    hybridBattleEndKey: '',
  };

  /// テスト用に差し替え可能な読み出し関数。nullなら Remote Config を使う。
  final String Function(String key)? _valueReader;

  /// アプリ起動時に1回呼ぶ。キャッシュ済みの値を即座に有効化し、
  /// 最新値の取得はバックグラウンドで行う（次回起動/次回読み出しで反映）。
  /// 機能フラグ用途なので最小取得間隔は1時間。Firebase未設定の環境では
  /// 例外を握りつぶし、全イベント非表示のまま動く。
  Future<void> initialize() async {
    if (_valueReader != null) return;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults(defaults);
      await rc.activate();
      unawaited(rc.fetchAndActivate().then((_) {}, onError: (_) {}));
    } catch (_) {
      // Firebase未初期化（プレースホルダー設定）など。イベントは非表示のまま。
    }
  }

  String _read(String key) {
    try {
      final reader = _valueReader;
      if (reader != null) return reader(key);
      return FirebaseRemoteConfig.instance.getString(key);
    } catch (_) {
      return '';
    }
  }

  EventWindow? _window(String startKey, String endKey) => EventWindow.tryParse(
        startIso: _read(startKey),
        endIso: _read(endKey),
      );

  EventWindow? get noveltyChessWindow =>
      _window(noveltyChessStartKey, noveltyChessEndKey);

  EventWindow? get hybridBattleWindow =>
      _window(hybridBattleStartKey, hybridBattleEndKey);
}
