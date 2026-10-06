// lib/logic.dart — 将棋ロジック & AI

import 'dart:math';

import 'piece.dart';
import 'ai_personality.dart';

// ===== GL: ゲームロジック =====
class GL {
  static bool ok(int r, int c) => r >= 0 && r < 9 && c >= 0 && c < 9;

  static List<List<Piece?>> copy(List<List<Piece?>> b) =>
      List.generate(9, (r) => List<Piece?>.from(b[r]));

  /// 平手初期盤面を生成
  static List<List<Piece?>> initialBoard() {
    final b = List.generate(
      9,
      (_) => List<Piece?>.filled(9, null, growable: false),
    );
    // 後手（isPlayer1=false, 上側, row 0-2）
    b[0][0] = const Piece(PieceType.lance, false);
    b[0][1] = const Piece(PieceType.knight, false);
    b[0][2] = const Piece(PieceType.silver, false);
    b[0][3] = const Piece(PieceType.gold, false);
    b[0][4] = const Piece(PieceType.king, false);
    b[0][5] = const Piece(PieceType.gold, false);
    b[0][6] = const Piece(PieceType.silver, false);
    b[0][7] = const Piece(PieceType.knight, false);
    b[0][8] = const Piece(PieceType.lance, false);
    b[1][1] = const Piece(PieceType.rook, false);
    b[1][7] = const Piece(PieceType.bishop, false);
    for (int c = 0; c < 9; c++) b[2][c] = const Piece(PieceType.pawn, false);
    // 先手（isPlayer1=true, 下側, row 6-8）
    for (int c = 0; c < 9; c++) b[6][c] = const Piece(PieceType.pawn, true);
    b[7][1] = const Piece(PieceType.bishop, true);
    b[7][7] = const Piece(PieceType.rook, true);
    b[8][0] = const Piece(PieceType.lance, true);
    b[8][1] = const Piece(PieceType.knight, true);
    b[8][2] = const Piece(PieceType.silver, true);
    b[8][3] = const Piece(PieceType.gold, true);
    b[8][4] = const Piece(PieceType.king, true);
    b[8][5] = const Piece(PieceType.gold, true);
    b[8][6] = const Piece(PieceType.silver, true);
    b[8][7] = const Piece(PieceType.knight, true);
    b[8][8] = const Piece(PieceType.lance, true);
    return b;
  }

  // 疑似合法手（王手放置を除外しない）
  static List<(int, int)> pseudo(List<List<Piece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    final p1 = piece.isPlayer1;
    final fwd = p1 ? -1 : 1;
    final moves = <(int, int)>[];

    bool can(int r, int c) =>
        ok(r, c) && (b[r][c] == null || b[r][c]!.isPlayer1 != p1);

    void step(int dr, int dc) {
      if (can(row + dr, col + dc)) moves.add((row + dr, col + dc));
    }

    void slide(int dr, int dc) {
      int r = row + dr, c = col + dc;
      while (ok(r, c)) {
        if (b[r][c] != null && b[r][c]!.isPlayer1 == p1) break;
        moves.add((r, c));
        if (b[r][c] != null) break;
        r += dr;
        c += dc;
      }
    }

    void gold() {
      step(fwd, -1);
      step(fwd, 0);
      step(fwd, 1);
      step(0, -1);
      step(0, 1);
      step(-fwd, 0);
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++)
          for (int dc = -1; dc <= 1; dc++) if (dr != 0 || dc != 0) step(dr, dc);
      case PieceType.rook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
      case PieceType.bishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
      case PieceType.gold:
        gold();
      case PieceType.silver:
        step(fwd, -1);
        step(fwd, 0);
        step(fwd, 1);
        step(-fwd, -1);
        step(-fwd, 1);
      case PieceType.knight:
        step(fwd * 2, -1);
        step(fwd * 2, 1);
      case PieceType.lance:
        slide(fwd, 0);
      case PieceType.pawn:
        step(fwd, 0);
      case PieceType.promotedRook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
        step(-1, -1);
        step(-1, 1);
        step(1, -1);
        step(1, 1);
      case PieceType.promotedBishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
        step(-1, 0);
        step(1, 0);
        step(0, -1);
        step(0, 1);
      default:
        gold(); // 成銀・成桂・成香・と金
    }
    return moves;
  }

  static (int, int)? kingPos(List<List<Piece?>> b, bool p1) {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.type == PieceType.king && p.isPlayer1 == p1)
          return (r, c);
      }
    return null;
  }

  static bool inCheck(List<List<Piece?>> b, bool p1) {
    final k = kingPos(b, p1);
    if (k == null) return false;
    return _kingAttacked(b, k, p1);
  }

  // king の位置が既知の場合の王手判定（kingPos の再スキャンを省略）
  static bool _kingAttacked(List<List<Piece?>> b, (int, int) k, bool p1) {
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isPlayer1 == p1) continue;
        if (pseudo(b, r, c).any((m) => m.$1 == k.$1 && m.$2 == k.$2))
          return true;
      }
    return false;
  }

  // 合法手（王手放置除外）
  static List<(int, int)> legal(List<List<Piece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    // 動かす駒が王でなければ、自玉の位置は候補手を通じて不変なので
    // 候補手ごとに kingPos を再スキャンする必要がない
    final isKingMove = piece.type == PieceType.king;
    final staticKingPos = isKingMove ? null : kingPos(b, piece.isPlayer1);
    return pseudo(b, row, col).where((dest) {
      final nb = copy(b);
      nb[dest.$1][dest.$2] = piece;
      nb[row][col] = null;
      final k = isKingMove ? dest : staticKingPos;
      if (k == null) return true; // 自玉が盤上にない（異常系）: 旧実装と同じ挙動
      return !_kingAttacked(nb, k, piece.isPlayer1);
    }).toList();
  }

  // 打てるマス
  static List<(int, int)> dropSquares(
    List<List<Piece?>> b,
    PieceType type,
    bool p1,
    Map<PieceType, int> hand,
    Map<PieceType, int> oppHand,
  ) {
    if ((hand[type] ?? 0) <= 0) return [];
    final squares = <(int, int)>[];
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        if (b[r][c] != null) continue;
        if (type == PieceType.pawn || type == PieceType.lance) {
          if (p1 && r == 0) continue;
          if (!p1 && r == 8) continue;
        }
        if (type == PieceType.knight) {
          if (p1 && r <= 1) continue;
          if (!p1 && r >= 7) continue;
        }
        // 二歩
        if (type == PieceType.pawn) {
          bool nifu = false;
          for (int rr = 0; rr < 9; rr++) {
            final p = b[rr][c];
            if (p != null && p.type == PieceType.pawn && p.isPlayer1 == p1) {
              nifu = true;
              break;
            }
          }
          if (nifu) continue;
        }
        final nb = copy(b);
        nb[r][c] = Piece(type, p1);
        if (inCheck(nb, p1)) continue;
        // 打ち歩詰め
        if (type == PieceType.pawn && _isPawnMate(nb, p1, oppHand)) continue;
        squares.add((r, c));
      }
    return squares;
  }

  static bool _isPawnMate(
    List<List<Piece?>> b,
    bool droppedByP1,
    Map<PieceType, int> oppHand,
  ) {
    final opp = !droppedByP1;
    if (!inCheck(b, opp)) return false;
    return !hasLegalMove(b, opp, oppHand);
  }

  // 駒が「効いている」マス（自駒のいるマスも含む・純粋な攻撃範囲）
  static List<(int, int)> threatens(List<List<Piece?>> b, int row, int col) {
    final piece = b[row][col];
    if (piece == null) return [];
    final p1 = piece.isPlayer1;
    final fwd = p1 ? -1 : 1;
    final sq = <(int, int)>[];

    void step(int dr, int dc) {
      final r = row + dr, c = col + dc;
      if (ok(r, c)) sq.add((r, c));
    }

    void slide(int dr, int dc) {
      int r = row + dr, c = col + dc;
      while (ok(r, c)) {
        sq.add((r, c));
        if (b[r][c] != null) break; // 駒があれば止まる（自駒でも敵駒でも）
        r += dr;
        c += dc;
      }
    }

    void gold() {
      step(fwd, -1);
      step(fwd, 0);
      step(fwd, 1);
      step(0, -1);
      step(0, 1);
      step(-fwd, 0);
    }

    switch (piece.type) {
      case PieceType.king:
        for (int dr = -1; dr <= 1; dr++)
          for (int dc = -1; dc <= 1; dc++) if (dr != 0 || dc != 0) step(dr, dc);
      case PieceType.rook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
      case PieceType.bishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
      case PieceType.gold:
        gold();
      case PieceType.silver:
        step(fwd, -1);
        step(fwd, 0);
        step(fwd, 1);
        step(-fwd, -1);
        step(-fwd, 1);
      case PieceType.knight:
        step(fwd * 2, -1);
        step(fwd * 2, 1);
      case PieceType.lance:
        slide(fwd, 0);
      case PieceType.pawn:
        step(fwd, 0);
      case PieceType.promotedRook:
        slide(-1, 0);
        slide(1, 0);
        slide(0, -1);
        slide(0, 1);
        step(-1, -1);
        step(-1, 1);
        step(1, -1);
        step(1, 1);
      case PieceType.promotedBishop:
        slide(-1, -1);
        slide(-1, 1);
        slide(1, -1);
        slide(1, 1);
        step(-1, 0);
        step(1, 0);
        step(0, -1);
        step(0, 1);
      default:
        gold();
    }
    return sq;
  }

  // 指定プレイヤーの全駒の効きマップ
  static List<List<int>> attackMap(List<List<Piece?>> b, bool p1) {
    final map = List.generate(9, (_) => List.filled(9, 0));
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final piece = b[r][c];
        if (piece == null || piece.isPlayer1 != p1) continue;
        for (final dest in threatens(b, r, c)) map[dest.$1][dest.$2]++;
      }
    return map;
  }

  static bool hasLegalMove(
    List<List<Piece?>> b,
    bool p1,
    Map<PieceType, int> hand, [
    Map<PieceType, int>? oppHand,
  ]) {
    oppHand ??= {};
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isPlayer1 != p1) continue;
        if (legal(b, r, c).isNotEmpty) return true;
      }
    for (final type in hand.keys) {
      if ((hand[type] ?? 0) <= 0) continue;
      if (dropSquares(b, type, p1, hand, oppHand).isNotEmpty) return true;
    }
    return false;
  }

  /// KifuMove を盤面・持ち駒に破壊的に適用する（感想戦・棋譜再生用）
  static void applyKifuMove(
    List<List<Piece?>> b,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    KifuMove move,
  ) {
    final isP1 = move.p1;
    final myHand = isP1 ? p1Hand : p2Hand;
    final oppHand = isP1 ? p2Hand : p1Hand;

    if (move.drop != null) {
      b[move.tr][move.tc] = Piece(move.drop!, isP1);
      myHand[move.drop!] = (myHand[move.drop!] ?? 1) - 1;
      if ((myHand[move.drop!] ?? 0) <= 0) myHand.remove(move.drop!);
    } else {
      if (move.fr < 0 || move.fc < 0) return;
      final piece = b[move.fr][move.fc];
      if (piece == null) return;
      final cap = b[move.tr][move.tc];
      if (cap != null) {
        final bt = cap.baseType;
        oppHand[bt] = (oppHand[bt] ?? 0) + 1;
      }
      b[move.tr][move.tc] = move.promote
          ? Piece(piece.promotedType, isP1)
          : piece;
      b[move.fr][move.fc] = null;
    }
  }
}

// ===== AI =====

// ── 置換表（Transposition Table）──────────────────────────────
enum _TTFlag { exact, alpha, beta }

class _TTEntry {
  final int score;
  final int depth;
  final _TTFlag flag;
  const _TTEntry(this.score, this.depth, this.flag);
}

// 駒の評価値（B: より正確なシステム値に改善）
const _val = {
  PieceType.pawn: 100,
  PieceType.lance: 250,
  PieceType.knight: 280,
  PieceType.silver: 440,
  PieceType.gold: 510,
  PieceType.bishop: 740,
  PieceType.rook: 880,
  PieceType.king: 10000,
  PieceType.promotedPawn: 530,
  PieceType.promotedLance: 530,
  PieceType.promotedKnight: 530,
  PieceType.promotedSilver: 530,
  PieceType.promotedBishop: 940,
  PieceType.promotedRook: 1040,
};

// ===== 千日手・持将棋判定 =====
class RepetitionChecker {
  final Map<String, int> _posCount = {};
  // 局面ハッシュ → その局面で手番プレイヤーが王手されていたか（初回記録時）
  final Map<String, bool> _posInCheck = {};

  /// 現局面を記録し、千日手かどうかを返す。
  /// [p1Turn] は次に指す手番（移動後の状態に対して呼ぶこと）。
  bool record(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool p1Turn,
  ) {
    final hash = _hash(board, p1Hand, p2Hand, p1Turn);
    // 初回訪問時に王手状態を記録
    if (!_posInCheck.containsKey(hash)) {
      _posInCheck[hash] = inCheck(board, p1Turn);
    }
    final count = (_posCount[hash] ?? 0) + 1;
    _posCount[hash] = count;
    return count >= 4;
  }

  /// 4回目の繰り返しが「連続王手による千日手」かどうかを返す。
  /// true の場合、手番プレイヤー（p1Turn 側）に王手をかけ続けた相手が負け。
  bool isConsecutiveCheck(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool p1Turn,
  ) {
    final hash = _hash(board, p1Hand, p2Hand, p1Turn);
    return _posInCheck[hash] ?? false;
  }

  void reset() {
    _posCount.clear();
    _posInCheck.clear();
  }

  // 現局面で p1Turn 側が王手されているか（inCheck の static wrapper）
  static bool inCheck(List<List<Piece?>> board, bool p1Turn) =>
      GL.inCheck(board, p1Turn);

  static String _hash(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
    bool p1Turn,
  ) {
    final buf = StringBuffer();
    buf.write(p1Turn ? '1' : '0');
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        buf.write(
          p == null ? '.' : '${p.isPlayer1 ? "P" : "p"}${p.type.index}',
        );
      }
    }
    // Map の挿入順（駒を取る/打つ順序）に依存すると同一局面が別ハッシュに
    // なってしまうため、駒種でソートしてから連結する
    final p1Entries = p1Hand.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    final p2Entries = p2Hand.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    for (final e in p1Entries) buf.write('H${e.key.index}=${e.value}');
    buf.write('|');
    for (final e in p2Entries) buf.write('h${e.key.index}=${e.value}');
    return buf.toString();
  }
}

/// 持将棋判定: 入玉点数計算
class NyugyokuChecker {
  /// 先手・後手それぞれの点数を返す（大駒=5点、小駒=1点）
  static (int p1Score, int p2Score) calcScores(
    List<List<Piece?>> board,
    Map<PieceType, int> p1Hand,
    Map<PieceType, int> p2Hand,
  ) {
    int p1 = 0, p2 = 0;
    // 持ち駒
    for (final e in p1Hand.entries) {
      p1 += _piecePoint(e.key) * e.value;
    }
    for (final e in p2Hand.entries) {
      p2 += _piecePoint(e.key) * e.value;
    }
    // 盤上の駒
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p == null || p.type == PieceType.king) continue;
        if (p.isPlayer1)
          p1 += _piecePoint(p.baseType);
        else
          p2 += _piecePoint(p.baseType);
      }
    }
    return (p1, p2);
  }

  static int _piecePoint(PieceType t) {
    switch (t) {
      case PieceType.rook:
      case PieceType.bishop:
        return 5;
      default:
        return 1;
    }
  }

  /// 入玉条件チェック（玉が敵陣3段目以内にいるか）
  static bool isNyugyoku(List<List<Piece?>> board, bool p1Turn) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = board[r][c];
        if (p == null || p.type != PieceType.king) continue;
        if (p.isPlayer1 && r <= 2) return true;
        if (!p.isPlayer1 && r >= 6) return true;
      }
    }
    return false;
  }
}

class AI {
  static final _rand = Random();

  // ── パーソナリティ（棋風設定）──────────────────────────────
  static AiPersonality? _personality;
  static bool _personalityAiIsP1 = true;

  /// 対局開始前に呼ぶ。personality=nullでデフォルト評価関数に戻る
  static void setPersonality(AiPersonality? personality, {bool aiIsP1 = true}) {
    _personality = personality;
    _personalityAiIsP1 = aiIsP1;
  }

  // ── 置換表・キラー手・ヒストリーテーブル ──────────────────────
  static final Map<String, _TTEntry> _tt = {};
  static const _ttMaxSize = 600000;
  static final List<List<AMove?>> _killers = List.generate(
    24,
    (_) => [null, null],
  );
  static final Map<String, int> _history = {};

  /// サーチ前にキラー・ヒストリーをリセット（TT は再利用）
  static void _clearSearchState() {
    for (final k in _killers) {
      k[0] = null;
      k[1] = null;
    }
    if (_history.length > 100000) _history.clear();
  }

  /// 局面ハッシュ（置換表キー用）
  static String _hash(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool turn,
  ) {
    final buf = StringBuffer();
    buf.writeCharCode(turn ? 49 : 48);
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null) {
          buf.writeCharCode(46);
        } else {
          buf.writeCharCode(p.isPlayer1 ? 65 : 97);
          buf.writeCharCode(p.type.index + 65);
        }
      }
    for (final e in p1h.entries)
      if (e.value > 0) {
        buf.writeCharCode(e.key.index + 48);
        buf.write(e.value);
      }
    buf.writeCharCode(124);
    for (final e in p2h.entries)
      if (e.value > 0) {
        buf.writeCharCode(e.key.index + 48);
        buf.write(e.value);
      }
    return buf.toString();
  }

  /// ヒストリーキー
  static String _hkey(AMove m) =>
      '${m.fr}${m.fc}${m.tr}${m.tc}${m.drop?.index ?? -1}';

  // ===== A. ムーブオーダリング =====
  // MVV-LVA: 取る手 > 成り > 打ち駒 > 静かな手 の順で探索
  static int _moveOrderScore(List<List<Piece?>> b, AMove mv) {
    if (mv.drop != null) {
      // 打ち駒: 価値の高い駒の打ちを優先
      return 200 + ((_val[mv.drop] ?? 0) ~/ 10);
    }
    final captured = b[mv.tr][mv.tc];
    if (captured != null) {
      // 取る手: MVV-LVA (取られる駒価値 高 - 取る駒価値 低) を優先
      final victimVal = _val[captured.type] ?? 0;
      final piece = b[mv.fr][mv.fc];
      final attackerVal = piece != null ? (_val[piece.type] ?? 0) : 0;
      return 10000 + victimVal * 10 - attackerVal;
    }
    if (mv.promote) return 800; // 成り手
    return 0; // 静かな手（最後に探索）
  }

  // 手をムーブオーダリングスコアでソート（キラー手・ヒストリー込み）
  static List<AMove> _sortMoves(List<List<Piece?>> b, List<AMove> moves) =>
      _sortMovesEx(b, moves, -1);

  static List<AMove> _sortMovesEx(
    List<List<Piece?>> b,
    List<AMove> moves,
    int depth,
  ) {
    if (moves.length <= 1) return moves;
    final k1 = (depth >= 0 && depth < 24) ? _killers[depth][0] : null;
    final k2 = (depth >= 0 && depth < 24) ? _killers[depth][1] : null;

    bool isKiller(AMove m, AMove? k) =>
        k != null &&
        m.fr == k.fr &&
        m.fc == k.fc &&
        m.tr == k.tr &&
        m.tc == k.tc &&
        m.drop == k.drop;

    final scored = moves.map((m) {
      int s = _moveOrderScore(b, m);
      if (s == 0) {
        // 静かな手: キラー > ヒストリー
        if (isKiller(m, k1))
          s = 950;
        else if (isKiller(m, k2))
          s = 900;
        else
          s = min(850, _history[_hkey(m)] ?? 0);
      }
      return (m, s);
    }).toList();
    scored.sort((a, z) => z.$2.compareTo(a.$2));
    return scored.map((e) => e.$1).toList();
  }

  // ===== B. 強化された評価関数 =====

  // 位置ボーナス（先手視点）
  static int _posBonus(PieceType t, int row, bool p1) {
    final rank = p1 ? (8 - row) : row; // 自陣=0, 敵陣=8
    switch (t) {
      case PieceType.pawn:
        return rank * 7; // 歩の前進を重視
      case PieceType.lance:
        return rank * 4;
      case PieceType.knight:
        return rank >= 2 ? rank * 5 : 0; // 桂は2段以上進んで価値あり
      case PieceType.silver:
        return rank * 3 + (rank >= 3 ? 10 : 0); // 敵陣侵入ボーナス
      case PieceType.gold:
        return rank * 2;
      case PieceType.bishop:
        return rank >= 3 ? (rank - 2) * 8 : 0; // 角は前線で強い
      case PieceType.rook:
        return rank >= 3 ? (rank - 2) * 8 : 0; // 飛は前線で強い
      case PieceType.king:
        return rank < 3 ? 25 : -(rank - 2) * 15; // 玉は自陣に留まる
      default:
        return rank * 3; // 成り駒の前進ボーナス
    }
  }

  // 玉の盾：周囲8マスの味方駒数 × 12点
  static int _kingShield(List<List<Piece?>> b, bool p1) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.type != PieceType.king || p.isPlayer1 != p1)
          continue;
        int shield = 0;
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final r2 = r + dr, c2 = c + dc;
            if (r2 >= 0 && r2 < 9 && c2 >= 0 && c2 < 9) {
              final nb = b[r2][c2];
              if (nb != null && nb.isPlayer1 == p1) shield++;
            }
          }
        }
        return shield * 12;
      }
    }
    return -5000;
  }

  /// 玉の危険度：近接する敵駒を駒種・距離で重み付け（先手玉への脅威を返す）
  static int _kingDanger(List<List<Piece?>> b, bool p1) {
    final k = GL.kingPos(b, p1);
    if (k == null) return 5000; // 玉なし=危険MAX
    final kr = k.$1, kc = k.$2;
    int danger = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isPlayer1 == p1) continue;
        final dist = (r - kr).abs() + (c - kc).abs();
        if (dist > 5) continue;
        final w = switch (p.type) {
          PieceType.rook || PieceType.promotedRook => 36,
          PieceType.bishop || PieceType.promotedBishop => 30,
          PieceType.promotedSilver ||
          PieceType.promotedKnight ||
          PieceType.promotedLance ||
          PieceType.promotedPawn => 22,
          PieceType.gold || PieceType.silver => 18,
          PieceType.knight || PieceType.lance => 12,
          PieceType.pawn => 5,
          _ => 8,
        };
        // 近いほど危険（dist=1: 4/2=2倍、dist=2: 4/3≈1.3倍、dist=3: 4/4=等倍）
        danger += (w * 4) ~/ (dist + 1);
      }
    }
    return danger;
  }

  /// 飛車オープンファイルボーナス（飛車の筋に自陣の歩がなければ+30）
  static int _rookOpenBonus(List<List<Piece?>> b, bool p1) {
    int bonus = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null || p.isPlayer1 != p1) continue;
        if (p.type != PieceType.rook && p.type != PieceType.promotedRook)
          continue;
        bool hasPawn = false;
        for (int rr = 0; rr < 9; rr++) {
          final pp = b[rr][c];
          if (pp != null && pp.isPlayer1 == p1 && pp.type == PieceType.pawn) {
            hasPawn = true;
            break;
          }
        }
        if (!hasPawn) bonus += 30;
      }
    }
    return bonus;
  }

  // ===== 強化版盤面評価（先手視点、正=先手有利） =====
  // ignorePersonality: 有利度バー・感想戦分析など「客観的な形勢」を示したい
  // 場面ではtrueにする。AI探索自体は棋風バイアスを使うためfalseのまま呼ぶ。
  static int eval(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h, {
    bool ignorePersonality = false,
  }) {
    final pers = ignorePersonality ? null : _personality;
    final aiIsP1 = _personalityAiIsP1;
    int score = 0;

    // ① 駒の価値 + 位置ボーナス（攻め傾向: AIの駒の前進ボーナスに攻め係数）
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p == null) continue;
        final base = _val[p.type] ?? 0;
        final rawPos = _posBonus(p.type, r, p.isPlayer1);
        int pos = rawPos;
        if (pers != null) {
          // AI自身の駒の前進ボーナスに攻め係数を適用
          final isAiPiece = p.isPlayer1 == aiIsP1;
          if (isAiPiece) pos = (rawPos * pers.attackBias).round();
        }
        // 駒得係数: AIの駒の素材価値に greedBias を乗算
        int pieceBase = base;
        if (pers != null && p.isPlayer1 == aiIsP1) {
          pieceBase = (base * pers.greedBias).round();
        }
        score += (p.isPlayer1 ? 1 : -1) * (pieceBase + pos);
      }
    }

    // ② 持ち駒の価値（AI側に greedBias 適用）
    final defHandWeight = 0.85;
    final aiHandWeight = pers != null ? (0.85 * pers.greedBias) : 0.85;
    if (aiIsP1) {
      for (final e in p1h.entries)
        score += e.value * ((_val[e.key] ?? 0) * aiHandWeight).round();
      for (final e in p2h.entries)
        score -= e.value * ((_val[e.key] ?? 0) * defHandWeight).round();
    } else {
      for (final e in p1h.entries)
        score += e.value * ((_val[e.key] ?? 0) * defHandWeight).round();
      for (final e in p2h.entries)
        score -= e.value * ((_val[e.key] ?? 0) * aiHandWeight).round();
    }

    // ③ 玉の盾（AI側の玉に defenceBias 適用）
    final aiShield = pers != null ? (pers.defenceBias) : 1.0;
    final oppShield = 1.0;
    if (aiIsP1) {
      score += (_kingShield(b, true) * aiShield).round();
      score -= (_kingShield(b, false) * oppShield).round();
    } else {
      score += (_kingShield(b, true) * oppShield).round();
      score -= (_kingShield(b, false) * aiShield).round();
    }

    // ④ 玉の危険度（AI自玉の危険度に defenceBias 適用）
    final aiDanger = pers != null ? pers.defenceBias : 1.0;
    final oppDanger = 1.0;
    if (aiIsP1) {
      score -= (_kingDanger(b, true) * aiDanger).round();
      score += (_kingDanger(b, false) * oppDanger).round();
    } else {
      score -= (_kingDanger(b, true) * oppDanger).round();
      score += (_kingDanger(b, false) * aiDanger).round();
    }

    // ⑤ 飛車オープンファイルボーナス（性格非依存: 常に両者同等）
    score += _rookOpenBonus(b, true);
    score -= _rookOpenBonus(b, false);

    return score;
  }

  // ===== D. クワイエッサンス探索 =====
  // depth=0の時、取り合いが続く場合は延長探索して地平線効果を防ぐ
  static int _qSearch(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    int alpha,
    int beta,
    bool maximizing,
    bool aiIsP1,
    int qDepth,
  ) {
    // stand-pat: 現在の静的評価（取り合いを強制しない権利）
    final standPat = eval(b, p1h, p2h);

    if (maximizing) {
      if (standPat >= beta) return standPat; // β枝刈り
      if (standPat > alpha) alpha = standPat;
    } else {
      if (standPat <= alpha) return standPat; // α枝刈り
      if (standPat < beta) beta = standPat;
    }

    if (qDepth <= 0) return standPat;

    // 取る手と成り手のみ生成
    final currP1 = maximizing == aiIsP1 ? aiIsP1 : !aiIsP1;
    final tactical = allMoves(b, currP1, p1h, p2h)
        .where(
          (mv) => mv.drop == null && (b[mv.tr][mv.tc] != null || mv.promote),
        )
        .toList();
    if (tactical.isEmpty) return standPat;

    // MVV-LVAで探索順をソート
    final sorted = _sortMoves(b, tactical);
    int val = standPat;

    for (final mv in sorted) {
      final next = apply(b, p1h, p2h, mv, currP1);
      final score = _qSearch(
        next.b,
        next.p1h,
        next.p2h,
        alpha,
        beta,
        !maximizing,
        aiIsP1,
        qDepth - 1,
      );
      if (maximizing) {
        val = max(val, score);
        alpha = max(alpha, val);
      } else {
        val = min(val, score);
        beta = min(beta, val);
      }
      if (beta <= alpha) break; // α-β枝刈り
    }
    return val;
  }

  // 全合法手を生成
  static List<AMove> allMoves(
    List<List<Piece?>> b,
    bool p1,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
  ) {
    final moves = <AMove>[];
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) {
        final piece = b[r][c];
        if (piece == null || piece.isPlayer1 != p1) continue;
        for (final dest in GL.legal(b, r, c)) {
          bool inZ(int row) => p1 ? row <= 2 : row >= 6;
          final canPro = piece.canPromote && (inZ(r) || inZ(dest.$1));
          if (canPro && !piece.mustPromote(dest.$1)) {
            moves.add(
              AMove(fr: r, fc: c, tr: dest.$1, tc: dest.$2, promote: false),
            );
            moves.add(
              AMove(fr: r, fc: c, tr: dest.$1, tc: dest.$2, promote: true),
            );
          } else {
            moves.add(
              AMove(
                fr: r,
                fc: c,
                tr: dest.$1,
                tc: dest.$2,
                promote: piece.mustPromote(dest.$1),
              ),
            );
          }
        }
      }
    final hand = p1 ? p1h : p2h;
    final oppHand = p1 ? p2h : p1h;
    for (final type in hand.keys) {
      for (final sq in GL.dropSquares(b, type, p1, hand, oppHand)) {
        moves.add(AMove(fr: -1, fc: -1, tr: sq.$1, tc: sq.$2, drop: type));
      }
    }
    return moves;
  }

  // ムーブを適用してコピーを返す
  static ({
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
  })
  apply(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    AMove mv,
    bool p1,
  ) {
    final nb = GL.copy(b);
    final np1h = Map<PieceType, int>.from(p1h);
    final np2h = Map<PieceType, int>.from(p2h);
    if (mv.drop != null) {
      nb[mv.tr][mv.tc] = Piece(mv.drop!, p1);
      final h = p1 ? np1h : np2h;
      h[mv.drop!] = (h[mv.drop!] ?? 1) - 1;
      if (h[mv.drop!] == 0) h.remove(mv.drop!);
    } else {
      final piece = nb[mv.fr][mv.fc]!;
      final cap = nb[mv.tr][mv.tc];
      if (cap != null) {
        final h = p1 ? np1h : np2h;
        final bt = cap.baseType;
        h[bt] = (h[bt] ?? 0) + 1;
      }
      nb[mv.tr][mv.tc] = mv.promote
          ? Piece(piece.promotedType, piece.isPlayer1)
          : piece;
      nb[mv.fr][mv.fc] = null;
    }
    return (b: nb, p1h: np1h, p2h: np2h);
  }

  // メインエントリ: 最善手を返す（depth=0でランダム）
  static AMove? bestMove(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1,
    int depth,
  ) {
    final moves = allMoves(b, aiIsP1, p1h, p2h);
    if (moves.isEmpty) return null;
    if (depth == 0) {
      moves.shuffle(_rand);
      return moves.first;
    }
    _clearSearchState();
    return _rootBestMove(b, p1h, p2h, aiIsP1, depth, moves);
  }

  // 反復深化 + 時間予算版 bestMove（UIスレッドをブロックしない前提でIsolate内から呼ぶ）
  static AMove? bestMoveTimed(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1, {
    Duration budget = const Duration(milliseconds: 900),
  }) {
    final moves = allMoves(b, aiIsP1, p1h, p2h);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first;

    // ── 詰み探索（9手詰めまで優先）──
    // 通常の α-β より高速に詰みを発見できる場合がある
    final mateMove = findMate(b, p1h, p2h, aiIsP1, maxDepth: 9);
    if (mateMove != null) return mateMove;

    _clearSearchState();
    final sw = Stopwatch()..start();
    AMove? best;
    for (int d = 1; d <= 10; d++) {
      final t0 = sw.elapsedMilliseconds;
      final candidate = _rootBestMove(b, p1h, p2h, aiIsP1, d, moves);
      if (candidate != null) best = candidate;
      final depthMs = sw.elapsedMilliseconds - t0;
      // 次の深さは約5倍かかると推定。予算を超えるなら打ち切り
      if (sw.elapsedMilliseconds + depthMs * 5 >= budget.inMilliseconds) break;
    }
    return best;
  }

  // 共通ルートサーチ（clearSearchState は呼び出し元の責任）
  static AMove? _rootBestMove(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1,
    int depth,
    List<AMove> moves,
  ) {
    final sortedMoves = _sortMoves(b, moves);
    AMove? best;
    int bestScore = aiIsP1 ? -999999 : 999999;
    for (final mv in sortedMoves) {
      final next = apply(b, p1h, p2h, mv, aiIsP1);
      final score = _mm(
        next.b,
        next.p1h,
        next.p2h,
        depth - 1,
        -999999,
        999999,
        !aiIsP1,
        aiIsP1,
      );
      final improved = aiIsP1 ? score > bestScore : score < bestScore;
      if (improved) {
        bestScore = score;
        best = mv;
      } else if (score == bestScore && _rand.nextDouble() < 0.25) {
        best = mv;
      }
    }
    return best;
  }

  // 上位 N 手を (move, score) のリストで返す
  static List<(AMove, int)> topMoves(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1,
    int depth, {
    int n = 3,
  }) {
    final moves = allMoves(b, aiIsP1, p1h, p2h);
    if (moves.isEmpty) return [];
    if (depth == 0) {
      moves.shuffle(_rand);
      return moves.take(n).map((m) => (m, 0)).toList();
    }
    _clearSearchState();
    return _rootTopMoves(b, p1h, p2h, aiIsP1, depth, moves, n);
  }

  // 反復深化 + 時間予算版 topMoves
  static List<(AMove, int)> topMovesTimed(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1, {
    int n = 3,
    Duration budget = const Duration(milliseconds: 600),
  }) {
    final moves = allMoves(b, aiIsP1, p1h, p2h);
    if (moves.isEmpty) return [];
    _clearSearchState();
    final sw = Stopwatch()..start();
    var best = <(AMove, int)>[];
    for (int d = 1; d <= 8; d++) {
      final t0 = sw.elapsedMilliseconds;
      final candidate = _rootTopMoves(b, p1h, p2h, aiIsP1, d, moves, n);
      if (candidate.isNotEmpty) best = candidate;
      final depthMs = sw.elapsedMilliseconds - t0;
      if (sw.elapsedMilliseconds + depthMs * 5 >= budget.inMilliseconds) break;
    }
    return best;
  }

  static List<(AMove, int)> _rootTopMoves(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool aiIsP1,
    int depth,
    List<AMove> moves,
    int n,
  ) {
    final scored = <(AMove, int)>[];
    final sortedMoves = _sortMoves(b, moves);
    for (final mv in sortedMoves) {
      final next = apply(b, p1h, p2h, mv, aiIsP1);
      final score = _mm(
        next.b,
        next.p1h,
        next.p2h,
        depth - 1,
        -999999,
        999999,
        !aiIsP1,
        aiIsP1,
      );
      scored.add((mv, score));
    }
    scored.sort((a, bb) => aiIsP1 ? bb.$2 - a.$2 : a.$2 - bb.$2);
    return scored.take(n).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // 詰み探索（最大 N 手詰め）
  // 攻め側は王手のみ、受け側は全手を試す再帰探索。
  // ノード数上限で打ち切り（時間超過防止）。
  // ─────────────────────────────────────────────────────────────

  static int _mateNodes = 0;
  static const int _maxMateNodes = 120000;

  /// 最大 maxDepth 手以内の詰み手を返す（詰みなし → null）。
  /// maxDepth は奇数（1, 3, 5, 7, 9, ...）推奨。
  static AMove? findMate(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool attackerIsP1, {
    int maxDepth = 9,
  }) {
    _mateNodes = 0;
    for (int d = 1; d <= maxDepth; d += 2) {
      // 攻め手の候補: 王手になる手のみ
      final atkMoves = allMoves(b, attackerIsP1, p1h, p2h).where((mv) {
        final nx = apply(b, p1h, p2h, mv, attackerIsP1);
        return GL.inCheck(nx.b, !attackerIsP1);
      }).toList();

      for (final mv in atkMoves) {
        if (_mateNodes >= _maxMateNodes) return null;
        final nx = apply(b, p1h, p2h, mv, attackerIsP1);
        if (_isMate(nx.b, nx.p1h, nx.p2h, attackerIsP1, d - 1)) {
          return mv;
        }
      }
    }
    return null;
  }

  /// 受け側の番。depth 手以内に全変化詰み → true
  static bool _isMate(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool attackerIsP1,
    int depth,
  ) {
    _mateNodes++;
    if (_mateNodes >= _maxMateNodes) return false;

    final defMoves = allMoves(b, !attackerIsP1, p1h, p2h);
    if (defMoves.isEmpty) return true; // 受けなし → 詰み
    if (depth == 0) return false; // 深さ切れ → 不詰み

    for (final mv in defMoves) {
      final nx = apply(b, p1h, p2h, mv, !attackerIsP1);
      if (!_canMate(nx.b, nx.p1h, nx.p2h, attackerIsP1, depth - 1)) {
        return false; // 少なくとも1変化逃げられる
      }
      if (_mateNodes >= _maxMateNodes) return false;
    }
    return true; // 全変化詰み
  }

  /// 攻め側の番。depth 手以内に詰みがある → true
  static bool _canMate(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    bool attackerIsP1,
    int depth,
  ) {
    _mateNodes++;
    if (_mateNodes >= _maxMateNodes) return false;
    if (depth == 0) return false;

    final atkMoves = allMoves(b, attackerIsP1, p1h, p2h).where((mv) {
      final nx = apply(b, p1h, p2h, mv, attackerIsP1);
      return GL.inCheck(nx.b, !attackerIsP1);
    }).toList();

    for (final mv in atkMoves) {
      final nx = apply(b, p1h, p2h, mv, attackerIsP1);
      if (_isMate(nx.b, nx.p1h, nx.p2h, attackerIsP1, depth - 1)) {
        return true;
      }
      if (_mateNodes >= _maxMateNodes) return false;
    }
    return false;
  }

  // 盤上の総駒数（null move pruning の終盤判定用）
  static int _totalPieces(List<List<Piece?>> b) {
    int n = 0;
    for (int r = 0; r < 9; r++)
      for (int c = 0; c < 9; c++) if (b[r][c] != null) n++;
    return n;
  }

  // ===== A+D+TT+Killer+NMP: 全最適化統合ミニマックス =====
  static int _mm(
    List<List<Piece?>> b,
    Map<PieceType, int> p1h,
    Map<PieceType, int> p2h,
    int depth,
    int alpha,
    int beta,
    bool maximizing,
    bool aiIsP1, {
    bool nullAllowed = true, // Null move pruning フラグ
  }) {
    final currP1 = maximizing == aiIsP1 ? aiIsP1 : !aiIsP1;
    final origAlpha = alpha;

    // ── 置換表ルックアップ ──
    final hash = _hash(b, p1h, p2h, currP1);
    final ttEntry = _tt[hash];
    if (ttEntry != null && ttEntry.depth >= depth) {
      final s = ttEntry.score;
      if (ttEntry.flag == _TTFlag.exact) return s;
      if (ttEntry.flag == _TTFlag.alpha) alpha = max(alpha, s);
      if (ttEntry.flag == _TTFlag.beta) beta = min(beta, s);
      if (alpha >= beta) return s;
    }

    // ── 葉ノード ──
    if (depth == 0) {
      final s = _qSearch(b, p1h, p2h, alpha, beta, maximizing, aiIsP1, 4);
      _tt[hash] = _TTEntry(s, 0, _TTFlag.exact);
      return s;
    }

    // ── Null Move Pruning（手番パスで β 超えなら枝刈り）──
    // 条件: depth≥3 / 王手でない / 終盤でない(総駒数>10) / 連続null禁止
    if (nullAllowed &&
        depth >= 3 &&
        !GL.inCheck(b, currP1) &&
        _totalPieces(b) > 10) {
      const R = 2; // 削減幅（depth - R - 1 = depth - 3）
      final nullVal = _mm(
        b,
        p1h,
        p2h,
        depth - R - 1,
        alpha,
        beta,
        !maximizing,
        aiIsP1,
        nullAllowed: false,
      );
      if (maximizing && nullVal >= beta) return beta;
      if (!maximizing && nullVal <= alpha) return alpha;
    }

    final moves = allMoves(b, currP1, p1h, p2h);
    if (moves.isEmpty) {
      return GL.inCheck(b, currP1) ? (maximizing ? -99999 : 99999) : 0;
    }

    // ── ムーブオーダリング（キラー手・ヒストリー込み）──
    final sorted = _sortMovesEx(b, moves, depth);

    int val = maximizing ? -999999 : 999999;
    final inCheckNow = GL.inCheck(b, currP1);
    for (int i = 0; i < sorted.length; i++) {
      final mv = sorted[i];
      final isCapture = mv.drop == null && b[mv.tr][mv.tc] != null;
      final isTactical = isCapture || mv.promote || inCheckNow;

      // ── LMR（Late Move Reductions）──
      // 後半の非戦術手を1〜2手浅く読む。αを超えたら全深度で再探索
      int reduction = 0;
      if (i >= 2 && depth >= 3 && !isTactical) {
        reduction = (i >= 6 && depth >= 5) ? 2 : 1;
      }

      final next = apply(b, p1h, p2h, mv, currP1);
      int child = _mm(
        next.b,
        next.p1h,
        next.p2h,
        depth - 1 - reduction,
        alpha,
        beta,
        !maximizing,
        aiIsP1,
      );

      // LMR 再探索: 削減あり & 有望な手だった場合
      if (reduction > 0) {
        final promising = maximizing ? child > alpha : child < beta;
        if (promising) {
          child = _mm(
            next.b,
            next.p1h,
            next.p2h,
            depth - 1,
            alpha,
            beta,
            !maximizing,
            aiIsP1,
          );
        }
      }

      if (maximizing) {
        val = max(val, child);
        alpha = max(alpha, val);
      } else {
        val = min(val, child);
        beta = min(beta, val);
      }
      if (beta <= alpha) {
        // ── β枝刈り: キラー手・ヒストリーを更新 ──
        if (mv.drop == null && _moveOrderScore(b, mv) == 0) {
          final di = depth < 24 ? depth : 23;
          _killers[di][1] = _killers[di][0];
          _killers[di][0] = mv;
          final hk = _hkey(mv);
          _history[hk] = (_history[hk] ?? 0) + depth * depth;
        }
        break;
      }
    }

    // ── 置換表に保存 ──
    if (_tt.length < _ttMaxSize) {
      final flag = val <= origAlpha
          ? _TTFlag.alpha
          : val >= beta
          ? _TTFlag.beta
          : _TTFlag.exact;
      _tt[hash] = _TTEntry(val, depth, flag);
    }
    return val;
  }
}
