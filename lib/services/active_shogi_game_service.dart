import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/active_shogi_game.dart';

/// 進行中AI対局のFirestore CRUD（komovia_goの`ActiveAiGameService`と
/// 同じ役割）。ドキュメントIDは常に`uid`なので、「進行中の対局があるか」
/// の判定は一覧クエリなしで単純な`doc(uid).get()`だけで済む。
class ActiveShogiGameService {
  ActiveShogiGameService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('active_shogi_games');

  Future<void> save(ActiveShogiGame game) {
    return _collection.doc(game.uid).set(game.toFirestore());
  }

  Future<ActiveShogiGame?> getActive(String uid) async {
    final doc = await _collection.doc(uid).get();
    if (!doc.exists) return null;
    return ActiveShogiGame.fromFirestore(doc);
  }

  Future<void> clear(String uid) {
    return _collection.doc(uid).delete();
  }
}
