import 'dart:math';

import 'package:komovia_core/komovia_core.dart';

import '../shogi_game.dart';
import '../shogi_position.dart';

/// 詰将棋の解答判定。1手詰では別解があり得るため、記録された解答手との
/// 一致ではなく「合法手で、指した直後に手番側（攻め方）の詰み勝ちになるか」
/// で判定する。打ち歩詰めなどの反則は [ShogiGame.legalMoves] 側で除外される。
class TsumeJudge {
  TsumeJudge._();

  static final _game = ShogiGame();

  static bool isMatingMove(ShogiPosition position, Move move) {
    if (!_game.legalMoves(position).contains(move)) return false;
    final result = _game.result(_game.apply(position, move));
    return result.winner == position.sideToMove &&
        result.reason == WinReason.checkmate;
  }
}

enum TsumeRushEndReason { timeUp, outOfLives, allSolved }

enum TsumeAnswer { correct, wrong }

/// 詰将棋ラッシュ1回分の状態（UIから独立した純粋ロジック）。
///
/// ルール: 制限時間 [duration]（既定3分）・ライフ [startingLives]（既定3）。
/// 正解で得点+1・連続正解+1して次の問題へ。不正解でライフ-1・連続正解が
/// 0に戻り、やり直しはせず次の問題へ進む（テンポ重視、lichess Puzzle
/// Storm/チェスの Puzzle Rush の3ミス制と同じ）。時間切れ・ライフ切れ・
/// 全問出題済みのいずれかで終了。
class TsumeRushSession {
  TsumeRushSession({
    required List<Puzzle<ShogiPosition>> puzzles,
    Random? random,
    this.duration = defaultDuration,
    this.startingLives = defaultLives,
  })  : _queue = List.of(puzzles)..shuffle(random ?? Random()),
        lives = startingLives;

  static const defaultDuration = Duration(minutes: 3);
  static const defaultLives = 3;

  final Duration duration;
  final int startingLives;
  final List<Puzzle<ShogiPosition>> _queue;
  int _index = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int lives;
  TsumeRushEndReason? endReason;

  bool get isFinished => endReason != null;
  int get puzzleCount => _queue.length;

  Puzzle<ShogiPosition>? get current =>
      isFinished || _index >= _queue.length ? null : _queue[_index];

  /// 現在の問題に対する着手を判定し、状態を進める。
  TsumeAnswer submit(Move move) {
    final puzzle = current;
    if (puzzle == null) throw StateError('Rush is finished');
    final ok = TsumeJudge.isMatingMove(puzzle.position, move);
    if (ok) {
      score++;
      streak++;
      bestStreak = max(bestStreak, streak);
    } else {
      streak = 0;
      lives--;
    }
    _index++;
    if (lives <= 0) {
      endReason = TsumeRushEndReason.outOfLives;
    } else if (_index >= _queue.length) {
      endReason = TsumeRushEndReason.allSolved;
    }
    return ok ? TsumeAnswer.correct : TsumeAnswer.wrong;
  }

  void timeUp() {
    endReason ??= TsumeRushEndReason.timeUp;
  }
}
