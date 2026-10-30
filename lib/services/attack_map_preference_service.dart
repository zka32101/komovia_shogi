import 'package:shared_preferences/shared_preferences.dart';

/// 駒の効き（利き）可視化トグルのオン/オフを永続化する。`kouki-shogi`の
/// 同機能（`kansousen_screen.dart`/`kifu_replay_screen.dart`）が使う
/// `review_show_attack_map`キーと同じ名前を使う — 両アプリの慣習を
/// 揃えておくことに実利はないが、komovia_shogi側でも画面間（AI対局・
/// PvP対局）で共有される単一のオン/オフ設定であることに変わりはない
/// ため、同じ単純なSharedPreferencesキー1個で十分。
class AttackMapPreferenceService {
  static const _key = 'review_show_attack_map';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
