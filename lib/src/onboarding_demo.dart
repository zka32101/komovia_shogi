import 'package:komovia_core/komovia_core.dart';

import 'piece.dart';
import 'shogi_position.dart';

/// A tiny hand-built position for [OnboardingScreen]'s interactive "capture
/// a piece" step: 先手の銀が後手の歩をすぐ前に取れるだけの、実戦とは無関係
/// の最小構成。駒を取る体験そのものを最短で体感させるためのもので、本物の
/// 対局の局面や定跡ではない。
ShogiPosition onboardingDemoPosition() {
  final board = List<List<Piece?>>.generate(9, (_) => List<Piece?>.filled(9, null));
  board[5][4] = const Piece(PieceType.silver, true);
  board[4][4] = const Piece(PieceType.pawn, false);
  return ShogiPosition(
    board: board,
    p1Hand: const {},
    p2Hand: const {},
    sideToMove: Side.first,
  );
}

/// The one legal move in [onboardingDemoPosition] that actually captures:
/// the silver stepping straight forward onto the pawn.
const onboardingDemoCaptureMove = BoardMove(
  from: Square(4, 5),
  to: Square(4, 4),
);
