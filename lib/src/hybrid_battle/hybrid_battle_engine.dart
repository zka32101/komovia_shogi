import '../logic.dart';
import '../piece.dart';

/// 番外編イベント「将棋駒 vs チェス駒」のルールエンジン。
///
/// 1枚の9x9盤の上で、片方は将棋の駒（本将棋の動き・成り）、もう片方は
/// チェスの駒（チェスの動き・プロモーション）で戦う、完全に新しい
/// 組み合わせのルール。既存のどのエンジンにも存在しないため、ここで
/// 自己完結した盤面/手番の状態機械として実装している。
///
/// ## 意図的に非対称なルール（ユーザー確認済み、対称に「直さない」こと）
///
/// * **持ち駒**: 取った駒を打てるのは**チェス側だけ**。将棋側が取った駒は
///   チェスと同じく盤上から永久に消える（将棋側に持ち駒は無い）。
///   チェス側が取った将棋駒は、[shogiToChessHand] の対応表でチェス駒に
///   変換して持ち駒になる（成駒は元の駒に戻してから変換）。
/// * **勝敗判定**: 各陣営の王は「相手陣営の流儀」で判定する。
///   * チェス側のキングは**将棋の詰み**ロジックで判定: 手番で合法手
///     （持ち駒打ちを含む）が1つも無ければ、王手の有無に関わらず負け
///     （将棋では合法手が無い=負け）。
///   * 将棋側の玉は**チェスのチェックメイト**ロジックで判定: 合法手が
///     無く王手されていればチェックメイト（チェス側の勝ち）、王手されて
///     いなければステイルメイト（引き分け）。
///
/// ## 初期配置（定まった歴史的配置は無いので独自に決めたもの）
///
/// 盤は行0が上、行8が下。
/// * 将棋側（下側, 先手, 上方向に進む）: 本将棋の先手と全く同じ配置
///   （行8に香桂銀金玉金銀桂香、行7に角・飛、行6に歩×9）。
/// * チェス側（上側, 後手, 下方向に進む）: 行0に R N B Q K B N R を
///   0〜7列に置き（キングは将棋の玉と同じ5筋=列4で向かい合う）、
///   9列目(列8)の最下段は空き。行1にポーン×9（9筋すべて）。
///   行2〜5の4段が空いた中間地帯になる。
///
/// ## 成り/プロモーション
/// * 将棋駒: 本将棋どおり。敵陣=盤の上3段（行0〜2）。行き所の無い駒は
///   強制成り、それ以外は任意（[HybridMove.promote] で選ぶ）。
/// * チェス駒: ポーンが最奥段（行8、将棋側の初期最下段）に到達したら
///   プロモーション。成る駒は Q/R/B/N から選べる（[HybridMove.chessPromotion]）。
///
/// ## チェス固有ルールの扱い
/// * ポーンの初手2マス前進: 初期位置（行1）からのみ可。
/// * キャスリング: キング・ルークが未移動で、間が空いており、キングが
///   通過・到着するマスが攻撃されていなければ可（標準チェスと同じ）。
/// * アンパッサン: 相手側に2マス前進するポーンが存在しないため、この
///   モードでは原理的に発生しない（実装不要）。
/// * 千日手・50手ルール等の引き分け規定は扱わない。
///
/// ## 将棋駒の動きの再利用
/// 将棋駒の動きは `GL.pseudo`（本アプリの将棋ルール）をそのまま使う。
/// 盤面を将棋の `Piece` 盤に射影し、チェス駒はすべて「相手側(後手)の
/// ダミー駒」として置くことで、取れる/取れないの判定も含めて本将棋と
/// 同一の動きになる。チェス駒は `package:chess` が8x8固定(0x88表現)で
/// 9x9盤に使えないため、標準チェスの動きをここで直接生成している。
enum HybridSide { shogi, chess }

enum ChessPieceType { pawn, knight, bishop, rook, queen, king }

class HybridPiece {
  const HybridPiece.shogi(PieceType this.shogiType)
      : side = HybridSide.shogi,
        chessType = null;
  const HybridPiece.chess(ChessPieceType this.chessType)
      : side = HybridSide.chess,
        shogiType = null;

  final HybridSide side;
  final PieceType? shogiType;
  final ChessPieceType? chessType;

  bool get isKing =>
      shogiType == PieceType.king || chessType == ChessPieceType.king;

  @override
  bool operator ==(Object other) =>
      other is HybridPiece &&
      other.side == side &&
      other.shogiType == shogiType &&
      other.chessType == chessType;

  @override
  int get hashCode => Object.hash(side, shogiType, chessType);
}

class HybridMove {
  const HybridMove({
    required this.toRow,
    required this.toCol,
    this.fromRow = -1,
    this.fromCol = -1,
    this.drop,
    this.promote = false,
    this.chessPromotion,
    this.isCastle = false,
  });

  final int fromRow, fromCol, toRow, toCol;

  /// チェス側の持ち駒打ち。nullなら盤上の移動。
  final ChessPieceType? drop;

  /// 将棋駒の成り。
  final bool promote;

  /// チェスのポーンのプロモーション先。
  final ChessPieceType? chessPromotion;

  final bool isCastle;

  bool get isDrop => drop != null;

  @override
  bool operator ==(Object other) =>
      other is HybridMove &&
      other.fromRow == fromRow &&
      other.fromCol == fromCol &&
      other.toRow == toRow &&
      other.toCol == toCol &&
      other.drop == drop &&
      other.promote == promote &&
      other.chessPromotion == chessPromotion;

  @override
  int get hashCode => Object.hash(
      fromRow, fromCol, toRow, toCol, drop, promote, chessPromotion);

  @override
  String toString() => isDrop
      ? 'drop $drop@($toRow,$toCol)'
      : '($fromRow,$fromCol)->($toRow,$toCol)'
          '${promote ? '+' : ''}${chessPromotion != null ? '=$chessPromotion' : ''}';
}

enum HybridResult { ongoing, shogiWins, chessWins, draw }

/// 取った将棋駒をチェス側の持ち駒にするときの対応表（独自の判断）。
/// 成駒は元の駒種に戻してから引く。玉は取られない（取られる前に
/// 詰み判定で終局する）ので対象外。
ChessPieceType shogiToChessHand(PieceType t) {
  switch (Piece(t, true).baseType) {
    case PieceType.rook:
      return ChessPieceType.rook;
    case PieceType.bishop:
    case PieceType.gold:
    case PieceType.silver:
      return ChessPieceType.bishop;
    case PieceType.knight:
      return ChessPieceType.knight;
    case PieceType.lance:
    case PieceType.pawn:
    default:
      return ChessPieceType.pawn;
  }
}

/// 盤面・手番・持ち駒・終局状態を持つイミュータブルな局面。
class HybridBattleState {
  HybridBattleState({
    required List<List<HybridPiece?>> board,
    required this.turn,
    required Map<ChessPieceType, int> chessHand,
    this.chessKingMoved = false,
    this.chessRookAMoved = false,
    this.chessRookHMoved = false,
  })  : board = List.unmodifiable(
            board.map((r) => List<HybridPiece?>.unmodifiable(r))),
        chessHand = Map.unmodifiable(chessHand);

  final List<List<HybridPiece?>> board;
  final HybridSide turn;
  final Map<ChessPieceType, int> chessHand;
  final bool chessKingMoved;

  /// 列0（左端）のルーク／列7のルークが動いた（または取られた）か。
  final bool chessRookAMoved;
  final bool chessRookHMoved;

  static const chessPawnStartRow = 1;
  static const chessPromotionRow = 8;

  factory HybridBattleState.initial() {
    final b = List.generate(9, (_) => List<HybridPiece?>.filled(9, null));
    final shogi = GL.initialBoard();
    for (var r = 6; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final p = shogi[r][c];
        if (p != null) b[r][c] = HybridPiece.shogi(p.type);
      }
    }
    const back = [
      ChessPieceType.rook,
      ChessPieceType.knight,
      ChessPieceType.bishop,
      ChessPieceType.queen,
      ChessPieceType.king,
      ChessPieceType.bishop,
      ChessPieceType.knight,
      ChessPieceType.rook,
    ];
    for (var c = 0; c < back.length; c++) {
      b[0][c] = HybridPiece.chess(back[c]);
    }
    for (var c = 0; c < 9; c++) {
      b[chessPawnStartRow][c] = const HybridPiece.chess(ChessPieceType.pawn);
    }
    return HybridBattleState(
        board: b, turn: HybridSide.shogi, chessHand: const {});
  }

  HybridPiece? at(int r, int c) => board[r][c];

  // ---------------------------------------------------------------------
  // 攻撃判定
  // ---------------------------------------------------------------------

  /// 将棋側をisPlayer1=true、チェス駒をすべて後手のダミー駒（金）として
  /// 射影した将棋盤。`GL.pseudo` に将棋駒の動きを生成させるために使う。
  static List<List<Piece?>> _shogiProjection(List<List<HybridPiece?>> b) =>
      List.generate(9, (r) {
        return List<Piece?>.generate(9, (c) {
          final p = b[r][c];
          if (p == null) return null;
          if (p.side == HybridSide.shogi) return Piece(p.shogiType!, true);
          return const Piece(PieceType.gold, false);
        });
      });

  /// チェス駒の「利き」（そのマスへ駒を取りに行けるか）。ポーンは斜め前のみ。
  static List<(int, int)> _chessAttacks(
      List<List<HybridPiece?>> b, int r, int c) {
    final t = b[r][c]!.chessType!;
    final out = <(int, int)>[];
    void step(int dr, int dc) {
      if (GL.ok(r + dr, c + dc)) out.add((r + dr, c + dc));
    }

    void slide(int dr, int dc) {
      var rr = r + dr, cc = c + dc;
      while (GL.ok(rr, cc)) {
        out.add((rr, cc));
        if (b[rr][cc] != null) break;
        rr += dr;
        cc += dc;
      }
    }

    switch (t) {
      case ChessPieceType.pawn:
        step(1, -1);
        step(1, 1);
      case ChessPieceType.knight:
        for (final d in const [
          (1, 2), (2, 1), (-1, 2), (-2, 1), //
          (1, -2), (2, -1), (-1, -2), (-2, -1),
        ]) {
          step(d.$1, d.$2);
        }
      case ChessPieceType.bishop:
        for (final d in const [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
          slide(d.$1, d.$2);
        }
      case ChessPieceType.rook:
        for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          slide(d.$1, d.$2);
        }
      case ChessPieceType.queen:
        for (final d in const [
          (1, 1), (1, -1), (-1, 1), (-1, -1), //
          (1, 0), (-1, 0), (0, 1), (0, -1),
        ]) {
          slide(d.$1, d.$2);
        }
      case ChessPieceType.king:
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr != 0 || dc != 0) step(dr, dc);
          }
        }
    }
    return out;
  }

  /// [by] 側のいずれかの駒が (r, c) に利いているか。
  static bool _isAttacked(
      List<List<HybridPiece?>> b, int r, int c, HybridSide by) {
    final proj = by == HybridSide.shogi ? _shogiProjection(b) : null;
    for (var rr = 0; rr < 9; rr++) {
      for (var cc = 0; cc < 9; cc++) {
        final p = b[rr][cc];
        if (p == null || p.side != by) continue;
        final targets = by == HybridSide.shogi
            ? GL.pseudo(proj!, rr, cc)
            : _chessAttacks(b, rr, cc);
        if (targets.any((t) => t.$1 == r && t.$2 == c)) return true;
      }
    }
    return false;
  }

  static (int, int)? _kingPos(List<List<HybridPiece?>> b, HybridSide side) {
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final p = b[r][c];
        if (p != null && p.side == side && p.isKing) return (r, c);
      }
    }
    return null;
  }

  static HybridSide _other(HybridSide s) =>
      s == HybridSide.shogi ? HybridSide.chess : HybridSide.shogi;

  static bool _inCheckOn(List<List<HybridPiece?>> b, HybridSide side) {
    final k = _kingPos(b, side);
    if (k == null) return false;
    return _isAttacked(b, k.$1, k.$2, _other(side));
  }

  /// [side] の王が現在王手（チェック）されているか。
  bool inCheck(HybridSide side) => _inCheckOn(board, side);

  // ---------------------------------------------------------------------
  // 合法手生成
  // ---------------------------------------------------------------------

  List<HybridMove> _pseudoMovesFrom(int r, int c) {
    final p = board[r][c];
    if (p == null) return const [];
    final moves = <HybridMove>[];
    if (p.side == HybridSide.shogi) {
      final piece = Piece(p.shogiType!, true);
      for (final (tr, tc) in GL.pseudo(_shogiProjection(board), r, c)) {
        final inZone = tr <= 2 || r <= 2;
        if (piece.mustPromote(tr)) {
          moves.add(HybridMove(
              fromRow: r, fromCol: c, toRow: tr, toCol: tc, promote: true));
          continue;
        }
        moves.add(HybridMove(fromRow: r, fromCol: c, toRow: tr, toCol: tc));
        if (piece.canPromote && inZone) {
          moves.add(HybridMove(
              fromRow: r, fromCol: c, toRow: tr, toCol: tc, promote: true));
        }
      }
      return moves;
    }

    final t = p.chessType!;
    bool enemyAt(int rr, int cc) =>
        board[rr][cc] != null && board[rr][cc]!.side == HybridSide.shogi;

    if (t == ChessPieceType.pawn) {
      void addPawn(int tr, int tc) {
        if (tr == chessPromotionRow) {
          for (final promo in const [
            ChessPieceType.queen,
            ChessPieceType.rook,
            ChessPieceType.bishop,
            ChessPieceType.knight,
          ]) {
            moves.add(HybridMove(
                fromRow: r,
                fromCol: c,
                toRow: tr,
                toCol: tc,
                chessPromotion: promo));
          }
        } else {
          moves.add(HybridMove(fromRow: r, fromCol: c, toRow: tr, toCol: tc));
        }
      }

      if (GL.ok(r + 1, c) && board[r + 1][c] == null) {
        addPawn(r + 1, c);
        if (r == chessPawnStartRow && board[r + 2][c] == null) {
          addPawn(r + 2, c);
        }
      }
      for (final dc in const [-1, 1]) {
        if (GL.ok(r + 1, c + dc) && enemyAt(r + 1, c + dc)) {
          addPawn(r + 1, c + dc);
        }
      }
      return moves;
    }

    for (final (tr, tc) in _chessAttacks(board, r, c)) {
      final dest = board[tr][tc];
      if (dest != null && dest.side == HybridSide.chess) continue;
      moves.add(HybridMove(fromRow: r, fromCol: c, toRow: tr, toCol: tc));
    }

    if (t == ChessPieceType.king && !chessKingMoved && r == 0 && c == 4) {
      bool safe(int cc) => !_isAttacked(board, 0, cc, HybridSide.shogi);
      bool rookAt(int cc) =>
          board[0][cc] == const HybridPiece.chess(ChessPieceType.rook);
      if (safe(4)) {
        // キングサイド: e→g（列4→6）、ルーク列7→5。
        if (!chessRookHMoved &&
            rookAt(7) &&
            board[0][5] == null &&
            board[0][6] == null &&
            safe(5) &&
            safe(6)) {
          moves.add(const HybridMove(
              fromRow: 0, fromCol: 4, toRow: 0, toCol: 6, isCastle: true));
        }
        // クイーンサイド: e→c（列4→2）、ルーク列0→3。
        if (!chessRookAMoved &&
            rookAt(0) &&
            board[0][1] == null &&
            board[0][2] == null &&
            board[0][3] == null &&
            safe(3) &&
            safe(2)) {
          moves.add(const HybridMove(
              fromRow: 0, fromCol: 4, toRow: 0, toCol: 2, isCastle: true));
        }
      }
    }
    return moves;
  }

  /// チェス側の持ち駒を打てるマス。空きマスであること、ポーンは
  /// 行0（自陣最下段=チェスでポーンが存在できない段）と行8（成らずに
  /// 存在できない最奥段）には打てない。二歩相当の制限は無い。
  List<(int, int)> dropSquares(ChessPieceType type) {
    if ((chessHand[type] ?? 0) <= 0) return const [];
    final out = <(int, int)>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board[r][c] != null) continue;
        if (type == ChessPieceType.pawn && (r == 0 || r == chessPromotionRow)) {
          continue;
        }
        out.add((r, c));
      }
    }
    return out;
  }

  bool _leavesKingSafe(HybridMove m) {
    final next = _applyRaw(m);
    return !_inCheckOn(next.board, turn);
  }

  /// (r, c) の駒の合法手（自玉を王手にさらす手を除く）。手番側の駒のみ。
  List<HybridMove> legalMovesFrom(int r, int c) {
    final p = board[r][c];
    if (p == null || p.side != turn) return const [];
    return _pseudoMovesFrom(r, c).where(_leavesKingSafe).toList();
  }

  /// 手番側のすべての合法手（チェス側は持ち駒打ちを含む。将棋側には
  /// 持ち駒が無い）。
  List<HybridMove> legalMoves() {
    final out = <HybridMove>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        out.addAll(legalMovesFrom(r, c));
      }
    }
    if (turn == HybridSide.chess) {
      for (final type in chessHand.keys) {
        for (final (r, c) in dropSquares(type)) {
          final m = HybridMove(toRow: r, toCol: c, drop: type);
          if (_leavesKingSafe(m)) out.add(m);
        }
      }
    }
    return out;
  }

  /// 指定手が合法なら適用した新しい局面を返し、不正ならnull。
  HybridBattleState? play(HybridMove m) {
    if (result != HybridResult.ongoing) return null;
    if (!legalMoves().contains(m)) return null;
    return _applyRaw(m);
  }

  HybridBattleState _applyRaw(HybridMove m) {
    final b = [for (final row in board) List<HybridPiece?>.from(row)];
    final hand = Map<ChessPieceType, int>.from(chessHand);
    var kingMoved = chessKingMoved;
    var rookA = chessRookAMoved;
    var rookH = chessRookHMoved;

    if (m.isDrop) {
      hand[m.drop!] = hand[m.drop!]! - 1;
      if (hand[m.drop!] == 0) hand.remove(m.drop!);
      b[m.toRow][m.toCol] = HybridPiece.chess(m.drop!);
    } else {
      final moving = b[m.fromRow][m.fromCol]!;
      final captured = b[m.toRow][m.toCol];
      if (captured != null) {
        if (moving.side == HybridSide.chess) {
          // チェス側だけが取った駒を持ち駒にできる。
          final h = shogiToChessHand(captured.shogiType!);
          hand[h] = (hand[h] ?? 0) + 1;
        } else {
          // 将棋側の取った駒は永久に消える（持ち駒にしない）。
          if (m.toRow == 0 && m.toCol == 0) rookA = true;
          if (m.toRow == 0 && m.toCol == 7) rookH = true;
        }
      }
      b[m.fromRow][m.fromCol] = null;
      if (moving.side == HybridSide.shogi) {
        b[m.toRow][m.toCol] = m.promote
            ? HybridPiece.shogi(Piece(moving.shogiType!, true).promotedType)
            : moving;
      } else {
        b[m.toRow][m.toCol] = m.chessPromotion != null
            ? HybridPiece.chess(m.chessPromotion!)
            : moving;
        if (moving.chessType == ChessPieceType.king) kingMoved = true;
        if (m.fromRow == 0 && m.fromCol == 0) rookA = true;
        if (m.fromRow == 0 && m.fromCol == 7) rookH = true;
        if (m.isCastle) {
          if (m.toCol == 6) {
            b[0][5] = b[0][7];
            b[0][7] = null;
          } else {
            b[0][3] = b[0][0];
            b[0][0] = null;
          }
        }
      }
    }
    return HybridBattleState(
      board: b,
      turn: _other(turn),
      chessHand: hand,
      chessKingMoved: kingMoved,
      chessRookAMoved: rookA,
      chessRookHMoved: rookH,
    );
  }

  // ---------------------------------------------------------------------
  // 終局判定（意図的に非対称）
  // ---------------------------------------------------------------------

  HybridResult? _result;

  HybridResult get result => _result ??= _computeResult();

  HybridResult _computeResult() {
    if (legalMoves().isNotEmpty) return HybridResult.ongoing;
    if (turn == HybridSide.chess) {
      // チェス側のキング = 将棋の詰みロジック: 合法手(打ちを含む)が無ければ負け。
      return HybridResult.shogiWins;
    }
    // 将棋側の玉 = チェスのロジック: チェックメイトなら負け、
    // ステイルメイトなら引き分け。
    return inCheck(HybridSide.shogi)
        ? HybridResult.chessWins
        : HybridResult.draw;
  }
}
