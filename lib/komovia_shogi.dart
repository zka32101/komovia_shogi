/// Shogi for Komovia: rules, AI, puzzles, kifu, and board rendering,
/// implementing komovia_core's Game/Engine/BoardRenderer interfaces.
///
/// Ported from 効棋 (zka32101/kouki-shogi). `ShogiGame`/`ShogiPosition`
/// (rules + SFEN notation) are ported; `Engine`/`BoardRenderer`
/// implementations are follow-ups — see the design doc (Komovia_共通基盤
/// 設計 §2c, §4) for the migration plan.
library;

export 'src/shogi_game.dart';
export 'src/shogi_position.dart';
