import 'package:cloud_firestore/cloud_firestore.dart';

/// 進行中（未終局）のAI対局のスナップショット。中断・再開機能専用。
///
/// komovia_goの`ActiveAiGame`と同じ設計 — 1ユーザーにつき同時に進行中の
/// AI対局は1つのみという前提で、FirestoreのドキュメントIDは常に`uid`
/// そのもの。盤面そのものは保存せず、`ShogiGame.exportRecord`/
/// `importRecord`が生成・解釈するKIF形式の棋譜文字列(`kifMoves`)だけを
/// 保存し、再開時はそれを初期局面から打ち直して盤面を再構成する —
/// 盤面を独自にFirestoreへエンコードする道を新たに増やさず、既に
/// テスト済みのKIFラウンドトリップをそのまま流用するため。
class ActiveShogiGame {
  final String uid;
  final String difficultyName;
  final String kifMoves;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ActiveShogiGame({
    required this.uid,
    required this.difficultyName,
    required this.kifMoves,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ActiveShogiGame.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ActiveShogiGame(
      uid: doc.id,
      difficultyName: data['difficultyName'] as String? ?? 'medium',
      kifMoves: data['kifMoves'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'difficultyName': difficultyName,
      'kifMoves': kifMoves,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt ?? DateTime.now()),
    };
  }
}
