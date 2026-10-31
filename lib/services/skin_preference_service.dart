import 'package:shared_preferences/shared_preferences.dart';

/// 選択中の盤スキン・駒セットスキン id をローカル（SharedPreferences）に
/// 永続化する。現状のスキンは全て無料で、端末ごとの見た目の好みに過ぎない
/// ため、[AttackMapPreferenceService] と同じくローカル保存で十分。
/// 有料スキン導入時に端末間同期が必要になれば UserProfile へ移す。
class SkinPreferenceService {
  static const boardKey = 'cosmetic_board_skin_id';
  static const pieceKey = 'cosmetic_piece_skin_id';

  Future<({String? board, String? piece})> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (board: prefs.getString(boardKey), piece: prefs.getString(pieceKey));
  }

  Future<void> setBoardSkin(String id) async =>
      (await SharedPreferences.getInstance()).setString(boardKey, id);

  Future<void> setPieceSkin(String id) async =>
      (await SharedPreferences.getInstance()).setString(pieceKey, id);
}
