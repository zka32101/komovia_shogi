/// Shogi for Komovia: rules, AI, puzzles, kifu, and board rendering,
/// implementing komovia_core's Game/Engine/BoardRenderer interfaces.
///
/// Ported from 効棋 (zka32101/kouki-shogi): `ShogiGame`/`ShogiPosition`
/// (rules + SFEN notation), `ShogiEngine` (AI), and `ShogiBoardRenderer`
/// (board rendering) — see the design doc (Komovia_共通基盤設計 §2c, §4)
/// for what's left (real KIF kifu notation, the richer textured board
/// background, an advantage overlay).
library;

export 'src/shogi_board_renderer.dart';
export 'src/shogi_engine.dart';
export 'src/shogi_game.dart';
export 'src/shogi_handicap_rule.dart';
export 'src/shogi_position.dart';
export 'src/shogi_puzzle.dart';
