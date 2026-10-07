import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/piece.dart';

void main() {
  final game = ShogiGame();

  group('ShogiPuzzle.fromTsumeJson', () {
    test('parses board, hands, title, and a drop-move solution', () {
      final flatBoard = List<String>.filled(81, '');
      flatBoard[0] = '-OU'; // 後手玉 at row 0, col 0
      flatBoard[80] = '+OU'; // 先手玉 at row 8, col 8 (keeps the board legal)

      final puzzle = ShogiPuzzle.fromTsumeJson(
        {
          'id': 'tsume-1',
          'title': '1手詰め ①',
          'board': flatBoard,
          'p1Hand': {'HI': 1},
          'p2Hand': <String, Object?>{},
          'solution': [
            {'fr': -1, 'fc': -1, 'tr': 0, 'tc': 1, 'drop': 'HI'},
          ],
          'difficulty': '初級',
          'moves': 1,
        },
        gameId: 'shogi',
      );

      expect(puzzle.id, 'tsume-1');
      expect(puzzle.gameId, 'shogi');
      expect(puzzle.title, '1手詰め ①');
      expect(puzzle.position.board[0][0]?.type, PieceType.king);
      expect(puzzle.position.board[0][0]?.isPlayer1, isFalse);
      expect(puzzle.position.board[8][8]?.isPlayer1, isTrue);
      expect(puzzle.position.p1Hand[PieceType.rook], 1);
      expect(puzzle.position.sideToMove, Side.first);
      expect(puzzle.metadata['difficulty'], '初級');
      expect(puzzle.metadata['totalMoves'], 1);

      expect(puzzle.solution, hasLength(1));
      final move = puzzle.solution.single as DropMove;
      expect(move.pieceType, PieceType.rook.name);
      expect(move.to, const Square(1, 0));

      // The puzzle's solution move is actually legal in the parsed
      // position — not just structurally well-formed.
      final applied = game.apply(puzzle.position, move);
      expect(applied.board[0][1]?.type, PieceType.rook);
    });

    test('a board move solution (non-drop) round-trips fr/fc/tr/tc', () {
      final puzzle = ShogiPuzzle.fromTsumeJson(
        {
          'id': 'tsume-2',
          'board': List<String>.filled(81, ''),
          'p1Hand': <String, Object?>{},
          'p2Hand': <String, Object?>{},
          'solution': [
            {'fr': 7, 'fc': 1, 'tr': 6, 'tc': 1, 'promote': true},
          ],
        },
        gameId: 'shogi',
      );

      final move = puzzle.solution.single as BoardMove;
      expect(move.from, const Square(1, 7));
      expect(move.to, const Square(1, 6));
      expect(move.promote, isTrue);
    });
  });

  group('ShogiPuzzle.fromLishogi', () {
    test('decodes the SFEN and parses USI solution moves', () {
      final sfen = game.encode(game.initialPosition());
      final puzzle = ShogiPuzzle.fromLishogi(
        id: '1234',
        gameId: 'shogi',
        sfen: sfen,
        solutionUsi: const ['7g7f'],
        rating: 1500,
        themes: const ['opening'],
      );

      expect(puzzle.id, '1234');
      expect(puzzle.title, 'lishogi #1234 (1500)');
      expect(puzzle.metadata['rating'], 1500);
      expect(puzzle.metadata['themes'], ['opening']);
      expect(game.encode(puzzle.position), sfen);

      final move = puzzle.solution.single as BoardMove;
      expect(move.from, const Square(2, 6));
      expect(move.to, const Square(2, 5));

      // "7g7f" is a real legal move from the standard initial position.
      final after = game.apply(puzzle.position, move);
      expect(after.board[5][2]?.type, PieceType.pawn);
      expect(after.board[6][2], isNull);
    });

    test('parses a drop move in USI notation ("P*5e")', () {
      final sfen = game.encode(game.initialPosition());
      final puzzle = ShogiPuzzle.fromLishogi(
        id: 'drop-1',
        gameId: 'shogi',
        sfen: sfen,
        solutionUsi: const ['P*5e'],
      );

      final move = puzzle.solution.single as DropMove;
      expect(move.pieceType, PieceType.pawn.name);
      expect(move.to, const Square(4, 4));
    });
  });
}
