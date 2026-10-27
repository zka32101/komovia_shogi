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

  /// [resignedBy] uses a sentinel default (not plain `Side? resignedBy`)
  /// so `copyWith(resignedBy: null)` can actually clear a resignation —
  /// `resignedBy ?? this.resignedBy` would silently keep the old value
  /// instead, the same copyWith anti-pattern fixed elsewhere in the
  /// Komovia family (see `Friendship.copyWith` in komovia_core).
  ShogiPosition copyWith({
    List<List<Piece?>>? board,
    Map<PieceType, int>? p1Hand,
    Map<PieceType, int>? p2Hand,
    Side? sideToMove,
    Object? resignedBy = _unset,
  }) {
    return ShogiPosition(
      board: board ?? this.board,
      p1Hand: p1Hand ?? this.p1Hand,
      p2Hand: p2Hand ?? this.p2Hand,
      sideToMove: sideToMove ?? this.sideToMove,
      resignedBy: resignedBy == _unset ? this.resignedBy : resignedBy as Side?,
    );
  }
}

/// Sentinel used by [ShogiPosition.copyWith] to distinguish "not passed"
/// from an explicit `null`, so [ShogiPosition.resignedBy] can actually be
/// cleared.
const Object _unset = Object();
