// AIをIsolate（別スレッド）で実行し、UIスレッドをブロックしないための
// エンコード/デコードヘルパーとトップレベルワーカー関数。
// `kouki-shogi`の`lib/services/ai_isolate.dart`と同じ方式（盤面・持ち駒を
// プリミティブなint配列にエンコードしてcompute()に渡す）だが、
// `ShogiEngine`が使う4つの操作（bestMove(level)・bestMoveTimed・eval・
// findMate）すべてに対応している点が異なる — 元の`AiIsolate`は
// `bestMoveTimed`/`topMovesTimed`/`findMate`のみで、レベル指定の
// `bestMove`と`eval`のIsolateラッパーは持っていなかった。
import 'logic.dart';
import 'piece.dart';

/// 盤面 → flat int リスト（81要素）。null=0, P1=type.index+1, P2=-(type.index+1)
List<int> encodeBoard(List<List<Piece?>> board) {
  final out = List<int>.filled(81, 0);
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      final p = board[r][c];
      if (p == null) continue;
      final v = p.type.index + 1;
      out[r * 9 + c] = p.isPlayer1 ? v : -v;
    }
  }
  return out;
}

List<List<Piece?>> decodeBoard(List<int> raw) {
  final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
  for (var r = 0; r < 9; r++) {
    for (var c = 0; c < 9; c++) {
      final v = raw[r * 9 + c];
      if (v == 0) continue;
      final type = PieceType.values[v.abs() - 1];
      board[r][c] = Piece(type, v > 0);
    }
  }
  return board;
}

/// 持ち駒 → 駒種ごとの枚数リスト（PieceType.values.length 要素）
List<int> encodeHand(Map<PieceType, int> hand) {
  final out = List<int>.filled(PieceType.values.length, 0);
  hand.forEach((type, count) => out[type.index] = count);
  return out;
}

Map<PieceType, int> decodeHand(List<int> raw) {
  final hand = <PieceType, int>{};
  for (var i = 0; i < raw.length; i++) {
    if (raw[i] > 0) hand[PieceType.values[i]] = raw[i];
  }
  return hand;
}

Map<String, Object?> positionParams(
  List<List<Piece?>> board,
  Map<PieceType, int> p1Hand,
  Map<PieceType, int> p2Hand,
  bool isP1,
) => {
  'board': encodeBoard(board),
  'p1h': encodeHand(p1Hand),
  'p2h': encodeHand(p2Hand),
  'isP1': isP1,
};

/// `compute()`に渡すトップレベル関数。トップレベル（またはstatic）関数
/// でないと別Isolateへ転送できない。

Map<String, Object?>? bestMoveLevelWorker(Map<String, Object?> p) {
  final board = decodeBoard((p['board'] as List).cast<int>());
  final p1Hand = decodeHand((p['p1h'] as List).cast<int>());
  final p2Hand = decodeHand((p['p2h'] as List).cast<int>());
  AI.setPersonality(null);
  final move = AI.bestMove(
    board,
    p1Hand,
    p2Hand,
    p['isP1'] as bool,
    p['level'] as int,
  );
  return move?.toJson();
}

Map<String, Object?>? bestMoveTimedWorker(Map<String, Object?> p) {
  final board = decodeBoard((p['board'] as List).cast<int>());
  final p1Hand = decodeHand((p['p1h'] as List).cast<int>());
  final p2Hand = decodeHand((p['p2h'] as List).cast<int>());
  AI.setPersonality(null);
  final move = AI.bestMoveTimed(
    board,
    p1Hand,
    p2Hand,
    p['isP1'] as bool,
    budget: Duration(milliseconds: p['budgetMs'] as int),
  );
  return move?.toJson();
}

double evaluateWorker(Map<String, Object?> p) {
  final board = decodeBoard((p['board'] as List).cast<int>());
  final p1Hand = decodeHand((p['p1h'] as List).cast<int>());
  final p2Hand = decodeHand((p['p2h'] as List).cast<int>());
  return AI
      .eval(board, p1Hand, p2Hand, ignorePersonality: true)
      .toDouble();
}

Map<String, Object?>? findMateWorker(Map<String, Object?> p) {
  final board = decodeBoard((p['board'] as List).cast<int>());
  final p1Hand = decodeHand((p['p1h'] as List).cast<int>());
  final p2Hand = decodeHand((p['p2h'] as List).cast<int>());
  AI.setPersonality(null);
  final move = AI.findMate(
    board,
    p1Hand,
    p2Hand,
    p['isP1'] as bool,
    maxDepth: p['maxDepth'] as int,
  );
  return move?.toJson();
}
