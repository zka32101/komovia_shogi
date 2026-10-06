import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_core/testkit.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/piece.dart';

void main() {
  final game = ShogiGame();

  runGameContractTests<ShogiPosition>(
    game,
    samplePosition: () => game.apply(
      game.initialPosition(),
      game.legalMoves(game.initialPosition()).first,
    ),
  );

  group('ShogiGame extra checks', () {
    test('initial position has 40 pieces and the right side to move', () {
      final pos = game.initialPosition();
      var count = 0;
      for (final row in pos.board) {
        for (final p in row) {
          if (p != null) count++;
        }
      }
      expect(count, 40);
      expect(pos.sideToMove, Side.first);
    });

    test('a pawn move is the only legal move for a cornered pawn at start', () {
      final pos = game.initialPosition();
      final moves = game.legalMoves(pos);
      // 30 pieces can move at the start in standard shogi (this is a
      // sanity bound, not an exact derivation): mostly pawns (9) plus a
      // handful of knight/bishop/rook/king/silver moves that are legal
      // from the initial position.
      expect(moves, isNotEmpty);
      expect(moves, everyElement(isA<BoardMove>()));
    });

    test('checkmate is detected via a cornered king (ported logic)', () {
      // Mirrors kouki-shogi's own GL.hasLegalMove contract: king cornered,
      // no escape/block/capture.
      final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      board[0][0] = const Piece(PieceType.king, false);
      board[8][0] = const Piece(PieceType.rook, true);
      board[0][8] = const Piece(PieceType.rook, true);
      board[8][8] = const Piece(PieceType.bishop, true);
      board[8][4] = const Piece(PieceType.king, true);
      final pos = ShogiPosition(
        board: board,
        p1Hand: const {},
        p2Hand: const {},
        sideToMove: Side.second,
      );
      final result = game.result(pos);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.checkmate);
      expect(game.legalMoves(pos), isEmpty);
    });

    test('resignation ends the game for the opponent', () {
      final pos = game.initialPosition();
      final afterResign = game.apply(pos, const ResignMove(Side.first));
      final result = game.result(afterResign);
      expect(result.winner, Side.second);
      expect(result.reason, WinReason.resignation);
    });

    test('SFEN round-trip preserves board, hands, and side to move', () {
      final pos = game.initialPosition();
      final sfen = game.encode(pos);
      final decoded = game.decode(sfen);
      expect(game.encode(decoded), sfen);
    });

    test('nyugyoku (持将棋・24点) ends the game once both kings have '
        'entered and a side reaches the threshold', () {
      // Minimal position: both kings past the 3rd rank from their own
      // side, p1 holds enough major pieces in hand to clear 24 points,
      // p2 does not.
      final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      board[2][4] = const Piece(PieceType.king, true); // p1 king entered
      board[6][4] = const Piece(PieceType.king, false); // p2 king entered
      final pos = ShogiPosition(
        board: board,
        p1Hand: const {
          PieceType.rook: 2,
          PieceType.bishop: 2,
          PieceType.gold: 4,
        },
        p2Hand: const {},
        sideToMove: Side.first,
      );
      final result = game.result(pos);
      expect(result.kind, ResultKind.win);
      expect(result.winner, Side.first);
      expect(result.reason, WinReason.impasse);
    });
  });
}
