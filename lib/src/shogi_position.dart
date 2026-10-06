import 'package:komovia_core/komovia_core.dart';

import 'piece.dart';

/// Shogi's [Position]: a 9x9 board (row-major, `board[row][col]`), both
/// hands, whose turn it is, and — if the game ended by resignation —
/// who resigned.
///
/// Row 0 is 後手's (Side.second's) back rank, row 8 is 先手's
/// (Side.first's) back rank, matching `kouki-shogi`'s `lib/logic.dart`.
class ShogiPosition extends Position {
  final List<List<Piece?>> board;
  final Map<PieceType, int> p1Hand;
  final Map<PieceType, int> p2Hand;

  @override
  final Side sideToMove;

  /// Set once a side resigns; null while the game continues normally.
  final Side? resignedBy;

  const ShogiPosition({
    required this.board,
    required this.p1Hand,
    required this.p2Hand,
    required this.sideToMove,
    this.resignedBy,
  });

  ShogiPosition copyWith({
    List<List<Piece?>>? board,
    Map<PieceType, int>? p1Hand,
    Map<PieceType, int>? p2Hand,
    Side? sideToMove,
    Side? resignedBy,
  }) {
    return ShogiPosition(
      board: board ?? this.board,
      p1Hand: p1Hand ?? this.p1Hand,
      p2Hand: p2Hand ?? this.p2Hand,
      sideToMove: sideToMove ?? this.sideToMove,
      resignedBy: resignedBy ?? this.resignedBy,
    );
  }
}
