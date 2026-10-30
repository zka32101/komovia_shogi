import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/src/hybrid_battle/hybrid_battle_engine.dart';
import 'package:komovia_shogi/src/piece.dart';

List<List<HybridPiece?>> emptyBoard() =>
    List.generate(9, (_) => List<HybridPiece?>.filled(9, null));

HybridPiece s(PieceType t) => HybridPiece.shogi(t);
HybridPiece c(ChessPieceType t) => HybridPiece.chess(t);

HybridBattleState pos(
  Map<(int, int), HybridPiece> pieces, {
  HybridSide turn = HybridSide.shogi,
  Map<ChessPieceType, int> hand = const {},
}) {
  final b = emptyBoard();
  pieces.forEach((k, v) => b[k.$1][k.$2] = v);
  return HybridBattleState(
    board: b,
    turn: turn,
    chessHand: hand,
    chessKingMoved: true,
    chessRookAMoved: true,
    chessRookHMoved: true,
  );
}

Set<(int, int)> dests(List<HybridMove> ms) =>
    ms.map((m) => (m.toRow, m.toCol)).toSet();

void main() {
  group('initial position', () {
    test('shogi side bottom, chess side top, shogi to move', () {
      final st = HybridBattleState.initial();
      expect(st.turn, HybridSide.shogi);
      expect(st.at(8, 4), s(PieceType.king));
      expect(st.at(0, 4), c(ChessPieceType.king));
      expect(st.at(0, 8), isNull);
      for (var col = 0; col < 9; col++) {
        expect(st.at(1, col), c(ChessPieceType.pawn));
        expect(st.at(6, col), s(PieceType.pawn));
      }
      expect(st.result, HybridResult.ongoing);
      // 歩9 + 香2 + 桂(1マス×2) ... 少なくとも歩の9手はある。
      expect(st.legalMoves().length, greaterThanOrEqualTo(9));
    });

    test('chess pawn may advance one or two squares from its start row', () {
      final st = HybridBattleState.initial()
          .play(const HybridMove(fromRow: 6, fromCol: 0, toRow: 5, toCol: 0))!;
      expect(st.turn, HybridSide.chess);
      expect(dests(st.legalMovesFrom(1, 3)), {(2, 3), (3, 3)});
      expect(dests(st.legalMovesFrom(0, 1)), {(2, 0), (2, 2)});
    });
  });

  group('move legality', () {
    test('shogi pieces move with native shogi movement (silver)', () {
      final st = pos({
        (8, 4): s(PieceType.king),
        (0, 0): c(ChessPieceType.king),
        (5, 4): s(PieceType.silver),
      });
      expect(dests(st.legalMovesFrom(5, 4)),
          {(4, 3), (4, 4), (4, 5), (6, 3), (6, 5)});
    });

    test('shogi piece can capture a chess piece', () {
      final st = pos({
        (8, 4): s(PieceType.king),
        (0, 0): c(ChessPieceType.king),
        (5, 4): s(PieceType.pawn),
        (4, 4): c(ChessPieceType.knight),
      });
      final next = st
          .play(const HybridMove(fromRow: 5, fromCol: 4, toRow: 4, toCol: 4))!;
      expect(next.at(4, 4), s(PieceType.pawn));
    });

    test('chess knight / bishop use native chess movement on 9x9', () {
      final st = pos({
        (8, 0): s(PieceType.king),
        (0, 8): c(ChessPieceType.king),
        (4, 4): c(ChessPieceType.knight),
        (2, 2): c(ChessPieceType.bishop),
      }, turn: HybridSide.chess);
      expect(dests(st.legalMovesFrom(4, 4)), {
        (2, 3),
        (2, 5),
        (3, 2),
        (3, 6),
        (5, 2),
        (5, 6),
        (6, 3),
        (6, 5),
      });
      // 角は(4,4)の自駒で止まる。
      expect(dests(st.legalMovesFrom(2, 2)),
          {(1, 1), (0, 0), (1, 3), (0, 4), (3, 1), (4, 0), (3, 3)});
    });

    test('chess pawn captures diagonally only, not straight ahead', () {
      final st = pos({
        (8, 0): s(PieceType.king),
        (0, 8): c(ChessPieceType.king),
        (4, 4): c(ChessPieceType.pawn),
        (5, 4): s(PieceType.gold),
        (5, 5): s(PieceType.silver),
      }, turn: HybridSide.chess);
      expect(dests(st.legalMovesFrom(4, 4)), {(5, 5)});
    });

    test('a move leaving own king in check is illegal', () {
      // 将棋側の金がチェスのルークに釘付け。
      final st = pos({
        (8, 4): s(PieceType.king),
        (7, 4): s(PieceType.gold),
        (2, 4): c(ChessPieceType.rook),
        (0, 0): c(ChessPieceType.king),
      });
      expect(st.legalMovesFrom(7, 4), isNotEmpty);
      // 金は縦にしか動けない（横・斜めは王手放置になる）。
      for (final m in st.legalMovesFrom(7, 4)) {
        expect(m.toCol, 4);
      }
    });

    test('shogi promotion is optional in zone and forced for dead-end pawn',
        () {
      final st = pos({
        (8, 4): s(PieceType.king),
        (0, 0): c(ChessPieceType.king),
        (3, 6): s(PieceType.silver),
        (1, 8): s(PieceType.pawn),
      });
      final silver = st.legalMovesFrom(3, 6).where((m) => m.toRow == 2);
      expect(silver.where((m) => m.promote), isNotEmpty);
      expect(silver.where((m) => !m.promote), isNotEmpty);
      final pawn = st.legalMovesFrom(1, 8);
      expect(pawn, hasLength(1));
      expect(pawn.single.promote, isTrue);
    });

    test('chess pawn promotes on reaching row 8 (shogi back rank)', () {
      final st = pos({
        (8, 0): s(PieceType.king),
        (0, 8): c(ChessPieceType.king),
        (7, 4): c(ChessPieceType.pawn),
      }, turn: HybridSide.chess);
      final ms = st.legalMovesFrom(7, 4);
      expect(ms.map((m) => m.chessPromotion).toSet(), {
        ChessPieceType.queen,
        ChessPieceType.rook,
        ChessPieceType.bishop,
        ChessPieceType.knight,
      });
      final next = st.play(
          ms.firstWhere((m) => m.chessPromotion == ChessPieceType.queen))!;
      expect(next.at(8, 4), c(ChessPieceType.queen));
    });

    test('chess castling kingside when path is clear and unattacked', () {
      final b = emptyBoard();
      b[0][4] = c(ChessPieceType.king);
      b[0][7] = c(ChessPieceType.rook);
      b[8][0] = s(PieceType.king);
      final st =
          HybridBattleState(board: b, turn: HybridSide.chess, chessHand: {});
      final castle = st.legalMovesFrom(0, 4).where((m) => m.isCastle);
      expect(castle, hasLength(1));
      final next = st.play(castle.single)!;
      expect(next.at(0, 6), c(ChessPieceType.king));
      expect(next.at(0, 5), c(ChessPieceType.rook));
    });
  });

  group('asymmetric mochigoma', () {
    test('chess side captures become droppable pieces in hand', () {
      final st = pos({
        (8, 0): s(PieceType.king),
        (0, 8): c(ChessPieceType.king),
        (4, 4): c(ChessPieceType.rook),
        (6, 4): s(PieceType.promotedSilver),
      }, turn: HybridSide.chess);
      final next = st
          .play(const HybridMove(fromRow: 4, fromCol: 4, toRow: 6, toCol: 4))!;
      // 成銀→銀→ビショップ
      expect(next.chessHand, {ChessPieceType.bishop: 1});
    });

    test('shogi side captures are removed permanently (no hand)', () {
      final st = pos({
        (8, 0): s(PieceType.king),
        (0, 8): c(ChessPieceType.king),
        (5, 4): s(PieceType.rook),
        (3, 4): c(ChessPieceType.queen),
      });
      final next = st
          .play(const HybridMove(fromRow: 5, fromCol: 4, toRow: 3, toCol: 4))!;
      expect(next.chessHand, isEmpty);
      final count = next.board.expand((r) => r).where((p) => p != null).length;
      expect(count, 3);
      // 将棋側の手番になっても打つ手は存在しない。
      final back = next
          .play(const HybridMove(fromRow: 0, fromCol: 8, toRow: 0, toCol: 7))!;
      expect(back.legalMoves().where((m) => m.isDrop), isEmpty);
    });

    test('chess side can drop on empty squares; pawns not on rows 0/8', () {
      final st = pos(
          {
            (8, 0): s(PieceType.king),
            (0, 8): c(ChessPieceType.king),
          },
          turn: HybridSide.chess,
          hand: {
            ChessPieceType.pawn: 2,
            ChessPieceType.knight: 1,
          });
      final drops = st.legalMoves().where((m) => m.isDrop).toList();
      final pawnDrops =
          dests(drops.where((m) => m.drop == ChessPieceType.pawn).toList());
      expect(pawnDrops.any((d) => d.$1 == 0 || d.$1 == 8), isFalse);
      expect(pawnDrops.contains((8, 0)), isFalse); // 占有マス
      // ナイトは空いている最下段にも打てる。
      final knightDrops =
          dests(drops.where((m) => m.drop == ChessPieceType.knight).toList());
      expect(knightDrops.contains((8, 5)), isTrue);
      expect(knightDrops.contains((0, 8)), isFalse); // 自キングがいる
      // 二歩相当の制限は無い: 同じ列に2枚目のポーンも打てる。
      final next = st.play(
          const HybridMove(toRow: 4, toCol: 4, drop: ChessPieceType.pawn))!;
      expect(
          next.chessHand, {ChessPieceType.pawn: 1, ChessPieceType.knight: 1});
      final again = next
          .play(const HybridMove(fromRow: 8, fromCol: 0, toRow: 8, toCol: 1))!;
      expect(
          again.play(
              const HybridMove(toRow: 6, toCol: 4, drop: ChessPieceType.pawn)),
          isNotNull);
    });
  });

  group('asymmetric win conditions', () {
    test('chess king mated (shogi tsumi logic) -> shogi wins', () {
      // 頭金: チェスのキング(0,4)、将棋の金(1,4)を歩(2,4)が支える。
      final st = pos({
        (0, 4): c(ChessPieceType.king),
        (1, 4): s(PieceType.gold),
        (2, 4): s(PieceType.pawn),
        (8, 0): s(PieceType.king),
      }, turn: HybridSide.chess);
      expect(st.inCheck(HybridSide.chess), isTrue);
      expect(st.result, HybridResult.shogiWins);
    });

    test('chess side escaping via a drop is not mate', () {
      // 飛車(6,0)の縦王手。キングの逃げ場は(1,0)=列0で利き、
      // (0,1)(1,1)は自駒で塞がっている。
      final pieces = {
        (0, 0): c(ChessPieceType.king),
        (0, 1): c(ChessPieceType.rook),
        (1, 1): c(ChessPieceType.pawn),
        (6, 0): s(PieceType.rook),
        (8, 8): s(PieceType.king),
      };
      // 持ち駒が無ければ将棋の詰み → 将棋側の勝ち。
      expect(
          pos(pieces, turn: HybridSide.chess).result, HybridResult.shogiWins);
      // 持ち駒のナイトを間に打てるので詰みではない。
      final st =
          pos(pieces, turn: HybridSide.chess, hand: {ChessPieceType.knight: 1});
      expect(st.result, HybridResult.ongoing);
      expect(dests(st.legalMoves()), {(1, 0), (2, 0), (3, 0), (4, 0), (5, 0)});
      expect(st.legalMoves().every((m) => m.isDrop), isTrue);
    });

    test('chess side with no legal moves but not in check still loses', () {
      final st = pos({
        (0, 0): c(ChessPieceType.king),
        (2, 0): s(PieceType.silver), // (1,0)(1,1)に利く
        (5, 1): s(PieceType.rook), // 列1: (1,1)(0,1)
        (8, 8): s(PieceType.king),
      }, turn: HybridSide.chess);
      expect(st.inCheck(HybridSide.chess), isFalse);
      expect(st.legalMoves(), isEmpty);
      expect(st.result, HybridResult.shogiWins);
    });

    test('shogi king checkmated (chess logic) -> chess wins', () {
      // 玉(8,0)、チェスのルーク2枚で最下段と7段目を押さえる。
      final st = pos({
        (8, 0): s(PieceType.king),
        (8, 7): c(ChessPieceType.rook),
        (7, 8): c(ChessPieceType.rook),
        (0, 4): c(ChessPieceType.king),
      });
      expect(st.inCheck(HybridSide.shogi), isTrue);
      expect(st.result, HybridResult.chessWins);
    });

    test('shogi king stalemated (chess logic) -> draw', () {
      // 玉(8,0)は王手されていないが、(7,0)(7,1)(8,1)がすべて利いている。
      final st = pos({
        (8, 0): s(PieceType.king),
        (6, 1): c(ChessPieceType.queen), // (7,0)(7,1)(8,1)? -> 列1と斜め
        (0, 4): c(ChessPieceType.king),
      });
      expect(st.inCheck(HybridSide.shogi), isFalse);
      expect(st.legalMoves(), isEmpty);
      expect(st.result, HybridResult.draw);
    });

    test('no further moves accepted after the game ends', () {
      final st = pos({
        (8, 0): s(PieceType.king),
        (8, 7): c(ChessPieceType.rook),
        (7, 8): c(ChessPieceType.rook),
        (0, 4): c(ChessPieceType.king),
      });
      expect(
          st.play(const HybridMove(fromRow: 8, fromCol: 0, toRow: 7, toCol: 0)),
          isNull);
    });
  });
}
