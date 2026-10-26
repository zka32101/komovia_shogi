import 'package:komovia_core/komovia_core.dart' as core;
import 'package:komovia_core/komovia_core.dart' show GameResult, ResultKind, Side;

import '../viewmodels/shogi_game_provider.dart' show ShogiDifficulty;

/// AI対局のレーティング計算。math自体はkomovia_core（`computeEloDelta`/
/// `ratingForAiLevel`）に集約済みで、ここは「将棋の難易度(`ShogiDifficulty`)
/// をどの仮想レーティングに対応させるか」という、このアプリ固有のマッピング
/// だけを持つ薄いラッパー（komovia_goの`lib/utils/ai_rating.dart`と同じ
/// 役割分担）。

/// 難易度に応じた仮想レーティング。`medium`を基準(1200)とし、1段階ごとに
/// ±200。beginner=800 / easy=1000 / medium=1200 / hard=1400。
int opponentRatingForDifficulty(ShogiDifficulty difficulty) {
  return core.ratingForAiLevel(
    level: difficulty.index + 1,
    minLevel: 1,
    maxLevel: ShogiDifficulty.values.length,
    baseLevel: ShogiDifficulty.medium.index + 1,
    step: 200,
  );
}

/// [result]が未確定(`ResultKind.ongoing`)の場合は`0`を返す。
int computeShogiRatingDelta({
  required int currentRating,
  required ShogiDifficulty difficulty,
  required GameResult result,
  required Side humanSide,
}) {
  if (result.kind == ResultKind.ongoing) return 0;
  final double score;
  if (result.kind == ResultKind.draw) {
    score = 0.5;
  } else if (result.winner == humanSide) {
    score = 1.0;
  } else {
    score = 0.0;
  }
  return core.computeEloDelta(
    currentRating: currentRating,
    opponentRating: opponentRatingForDifficulty(difficulty),
    score: score,
  );
}
