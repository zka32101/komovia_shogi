import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/piece.dart';

void main() {
  final game = ShogiGame();

  group('KIF export — exact notation', () {
    test('the first legal move from the initial position is 9六歩(97)', () {
      // Locks in the actual KIF notation algorithm (file/rank conversion,
      // piece label, parenthesized source square), not just round-trip
      // stability.
      final pos = game.initialPosition();
      final move = game.legalMoves(pos).first;
      final record = GameRecord(
        gameId: 'shogi',
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        result: GameResult.ongoing,
      );
      final kif = game.exportRecord(record);
      expect(kif, contains('   1 9六歩(97)   00:00'));
    });

    test('a drop move is rendered as "{file}{rank}{piece}打"', () {
      final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
      board[0][0] = const Piece(PieceType.king, false);
      board[8][4] = const Piece(PieceType.king, true);
      final pos = ShogiPosition(
        board: board,
        p1Hand: const {PieceType.rook: 1},
        p2Hand: const {},
        sideToMove: Side.first,
      );
      final move = DropMove(pieceType: PieceType.rook.name, to: Square(4, 4));
      final record = GameRecord(
        gameId: 'shogi',
        initialPositionNotation: game.encode(pos),
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        result: GameResult.ongoing,
      );
      expect(game.exportRecord(record), contains('5五飛打'));
    });
  });

  group('KIF export/import — result trailers', () {
    test('resignation: trailer names the resigning side as the loser', () {
      final record = GameRecord(
        gameId: 'shogi',
        moves: const [],
        result: GameResult.win(Side.first, WinReason.resignation),
      );
      final kif = game.exportRecord(record);
      expect(kif, contains('1 投了'));
      expect(kif, contains('まで0手で後手の負け（先手勝ち）'));

      final imported = game.importRecord(kif);
      expect(imported.result.kind, ResultKind.win);
      expect(imported.result.winner, Side.first);
      expect(imported.result.reason, WinReason.resignation);
    });

    test('checkmate (no resignation line): trailer still names the winner', () {
      final record = GameRecord(
        gameId: 'shogi',
        moves: const [],
        result: GameResult.win(Side.second, WinReason.checkmate),
      );
      final kif = game.exportRecord(record);
      expect(kif, isNot(contains('投了')));
      expect(kif, contains('まで0手で先手の負け（後手勝ち）'));

      final imported = game.importRecord(kif);
      expect(imported.result.winner, Side.second);
      expect(imported.result.reason, WinReason.checkmate);
    });

    test('a draw trailer round-trips as a draw (specific reason is lossy)', () {
      final record = GameRecord(
        gameId: 'shogi',
        moves: const [],
        result: const GameResult.draw(WinReason.impasse),
      );
      final kif = game.exportRecord(record);
      expect(kif, contains('まで0手で引き分け'));

      final imported = game.importRecord(kif);
      expect(imported.result.kind, ResultKind.draw);
      // Re-exporting still produces the same text even though the
      // specific WinReason wasn't preserved.
      expect(game.exportRecord(imported), kif);
    });

    test('an ongoing game (no trailer) imports as ongoing', () {
      final pos = game.initialPosition();
      final move = game.legalMoves(pos).first;
      final record = GameRecord(
        gameId: 'shogi',
        moves: [RecordedMove(number: 1, side: Side.first, move: move)],
        result: GameResult.ongoing,
      );
      final kif = game.exportRecord(record);
      expect(game.importRecord(kif).result.isOngoing, isTrue);
    });
  });

  group('KIF import — player names', () {
    test('先手／後手 lines round-trip into metadata', () {
      final record = GameRecord(
        gameId: 'shogi',
        moves: const [],
        result: GameResult.ongoing,
        metadata: const {'p1Name': 'かずき', 'p2Name': 'Komovia AI'},
      );
      final kif = game.exportRecord(record);
      expect(kif, contains('先手：かずき'));
      expect(kif, contains('後手：Komovia AI'));

      final imported = game.importRecord(kif);
      expect(imported.metadata['p1Name'], 'かずき');
      expect(imported.metadata['p2Name'], 'Komovia AI');
    });
  });

  group('KIF import — a real played-out game', () {
    test(
        'replaying imported moves from the standard start reaches the '
        'same position as the original game', () {
      // Import only supports 手合割：平手 (standard start, see
      // shogi_game.dart's "known simplifications" note), so this plays a
      // short opening from the real initial position rather than a
      // custom/handicap board.
      var pos = game.initialPosition();
      final moves = <RecordedMove>[];
      for (var i = 0; i < 8; i++) {
        final move = game.legalMoves(pos).first;
        moves
            .add(RecordedMove(number: i + 1, side: pos.sideToMove, move: move));
        pos = game.apply(pos, move);
      }
      final originalEncoded = game.encode(pos);
      final record = GameRecord(
        gameId: 'shogi',
        moves: moves,
        result: GameResult.ongoing,
      );

      final kif = game.exportRecord(record);
      final imported = game.importRecord(kif);
      expect(imported.moves, hasLength(moves.length));

      var replay = game.initialPosition();
      for (final m in imported.moves) {
        replay = game.apply(replay, m.move);
      }
      expect(game.encode(replay), originalEncoded);
    });
  });
}
