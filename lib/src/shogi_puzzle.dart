import 'package:komovia_core/komovia_core.dart';

import 'piece.dart';
import 'shogi_game.dart';
import 'shogi_position.dart';

/// Converts `kouki-shogi`'s puzzle sources (hand-made 詰将棋 JSON, lishogi
/// imports, 手筋 drills — see `lib/models/unified_puzzle.dart`) into
/// `komovia_core`'s game-agnostic `Puzzle<ShogiPosition>`.
///
/// Only the data-shape conversion is ported here; `UnifiedPuzzle` also
/// carries presentation-only fields (`difficultyLabel`, `typeLabel`) that
/// stay app-side and land in [Puzzle.metadata] instead, since
/// `komovia_core` has no shogi-specific vocabulary.
class ShogiPuzzle {
  ShogiPuzzle._();

  static const _pieceCodes = {
    'OU': PieceType.king,
    'HI': PieceType.rook,
    'KA': PieceType.bishop,
    'KI': PieceType.gold,
    'GI': PieceType.silver,
    'KE': PieceType.knight,
    'KY': PieceType.lance,
    'FU': PieceType.pawn,
    'RY': PieceType.promotedRook,
    'UM': PieceType.promotedBishop,
    'NG': PieceType.promotedSilver,
    'NK': PieceType.promotedKnight,
    'NY': PieceType.promotedLance,
    'TO': PieceType.promotedPawn,
  };

  static PieceType? _parsePieceCode(String code) =>
      _pieceCodes[code.toUpperCase()];

  /// A hand-made 詰将棋/手筋 puzzle, as stored in `tsume_extra.json` /
  /// `tesuji_problems.dart`: a flat 81-cell board (`"+FU"`/`"-OU"`/`""`),
  /// per-side hand counts, and a structured move-by-move solution —
  /// ported from `UnifiedPuzzle.fromTsumeJson`/`_parseFlatBoard`.
  ///
  /// [sideToMove] defaults to [Side.first] since tsume puzzles are
  /// conventionally posed with 先手 to move (`UnifiedPuzzle`'s
  /// `isPlayer1Turn: true` for this source).
  static Puzzle<ShogiPosition> fromTsumeJson(
    Map<String, Object?> json, {
    required String gameId,
    Side sideToMove = Side.first,
  }) {
    final flatBoard = (json['board'] as List).cast<String>();
    final board = List.generate(9, (_) => List<Piece?>.filled(9, null));
    for (var i = 0; i < flatBoard.length && i < 81; i++) {
      final cell = flatBoard[i];
      if (cell.isEmpty) continue;
      final isP1 = cell.startsWith('+');
      final type = _parsePieceCode(cell.substring(1));
      if (type != null) board[i ~/ 9][i % 9] = Piece(type, isP1);
    }

    Map<PieceType, int> parseHand(Object? raw) {
      final hand = <PieceType, int>{};
      for (final entry in (raw as Map<String, Object?>? ?? const {}).entries) {
        final type = _parsePieceCode(entry.key);
        if (type != null) hand[type] = entry.value as int;
      }
      return hand;
    }

    final position = ShogiPosition(
      board: board,
      p1Hand: parseHand(json['p1Hand']),
      p2Hand: parseHand(json['p2Hand']),
      sideToMove: sideToMove,
    );

    final rawSolution = (json['solution'] as List).cast<Map<String, Object?>>();
    final solution = rawSolution.map((step) {
      final dropCode = step['drop'] as String?;
      final drop = dropCode != null ? _parsePieceCode(dropCode) : null;
      final to = Square(step['tc'] as int, step['tr'] as int);
      if (drop != null) {
        return DropMove(pieceType: drop.name, to: to);
      }
      return BoardMove(
        from: Square(step['fc'] as int, step['fr'] as int),
        to: to,
        promote: step['promote'] as bool? ?? false,
      );
    }).toList();

    return Puzzle(
      id: json['id'] as String,
      gameId: gameId,
      position: position,
      solution: solution,
      title: json['title'] as String?,
      metadata: {
        if (json['difficulty'] != null) 'difficulty': json['difficulty'],
        if (json['moves'] != null) 'totalMoves': json['moves'],
      },
    );
  }

  /// A lishogi-imported puzzle: the position as an SFEN string (decoded
  /// via [ShogiGame.decode]) and the solution as USI move strings
  /// (`"7g7f"`, `"P*5e"`, `"8h2b+"`) — ported from
  /// `UnifiedPuzzle.fromLishogi` and `lishogi_service.dart`'s
  /// `UsiParser.parse`.
  static Puzzle<ShogiPosition> fromLishogi({
    required String id,
    required String gameId,
    required String sfen,
    required List<String> solutionUsi,
    int? rating,
    List<String>? themes,
  }) {
    final game = ShogiGame();
    final position = game.decode(sfen);
    final solution = solutionUsi.map(_parseUsiMove).toList();

    return Puzzle(
      id: id,
      gameId: gameId,
      position: position,
      solution: solution,
      title: rating != null ? 'lishogi #$id ($rating)' : 'lishogi #$id',
      metadata: {
        if (rating != null) 'rating': rating,
        if (themes != null) 'themes': themes,
      },
    );
  }

  static const _usiPieceCodes = {
    'R': PieceType.rook,
    'B': PieceType.bishop,
    'G': PieceType.gold,
    'S': PieceType.silver,
    'N': PieceType.knight,
    'L': PieceType.lance,
    'P': PieceType.pawn,
  };

  /// Parses one USI move (`fileRank` using `1`-`9` files and `a`-`i`
  /// ranks, e.g. `"7g7f"`, or a drop `"P*5e"`) into a [Move]. Board
  /// coordinates follow the same `(row, col)` convention as
  /// `ShogiPosition.board` (row 0 = 後手's back rank), matching
  /// `UsiParser.parse`'s `toRow`/`toCol` conversion.
  static Move _parseUsiMove(String usi) {
    int colOf(String fileChar) => 9 - int.parse(fileChar);
    int rowOf(String rankChar) => rankChar.codeUnitAt(0) - 'a'.codeUnitAt(0);

    if (usi.length >= 4 && usi[1] == '*') {
      final type = _usiPieceCodes[usi[0].toUpperCase()];
      if (type == null) {
        throw FormatException('Unknown drop piece in USI move: $usi');
      }
      return DropMove(
        pieceType: type.name,
        to: Square(colOf(usi[2]), rowOf(usi[3])),
      );
    }

    if (usi.length < 4) {
      throw FormatException('USI move too short: $usi');
    }
    return BoardMove(
      from: Square(colOf(usi[0]), rowOf(usi[1])),
      to: Square(colOf(usi[2]), rowOf(usi[3])),
      promote: usi.length > 4 && usi[4] == '+',
    );
  }
}
