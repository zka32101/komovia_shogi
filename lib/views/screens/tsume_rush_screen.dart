import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/tsume/tsume_logic.dart';
import 'package:komovia_shogi/src/tsume/tsume_problems.dart';

import '../../l10n/app_localizations.dart';
import '../../services/tsume_rush_service.dart';
import '../../viewmodels/index.dart';
import '../widgets/tsume_board.dart';

/// 詰将棋ラッシュ: 制限時間内に1手詰を次々と解く。ルールは
/// [TsumeRushSession] を参照（3分・ライフ3・不正解は次の問題へ）。
/// 終了時に自己ベストを Firestore（`users/{uid}/tsume_rush/stats`）に記録。
class TsumeRushScreen extends ConsumerStatefulWidget {
  const TsumeRushScreen({
    super.key,
    required this.uid,
    this.puzzles,
    this.duration = TsumeRushSession.defaultDuration,
    this.random,
  });

  final String uid;
  final List<Puzzle<ShogiPosition>>? puzzles;
  final Duration duration;
  final Random? random;

  @override
  ConsumerState<TsumeRushScreen> createState() => _TsumeRushScreenState();
}

class _TsumeRushScreenState extends ConsumerState<TsumeRushScreen> {
  TsumeRushSession? _session;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  TsumeAnswer? _lastAnswer;
  TsumeRushStats? _savedStats;
  bool _newBest = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _session = TsumeRushSession(
        puzzles: widget.puzzles ?? builtInTsumeProblems(),
        random: widget.random,
        duration: widget.duration,
      );
      _remaining = widget.duration;
      _lastAnswer = null;
      _savedStats = null;
      _newBest = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
          _session!.timeUp();
        });
        _finish();
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  void _onMove(Move move) {
    final session = _session!;
    final answer = session.submit(move);
    setState(() => _lastAnswer = answer);
    if (session.isFinished) _finish();
  }

  Future<void> _finish() async {
    _timer?.cancel();
    final session = _session!;
    final service = ref.read(tsumeRushServiceProvider);
    try {
      final stats = await service.recordRun(
        widget.uid,
        score: session.score,
        bestStreak: session.bestStreak,
      );
      if (!mounted) return;
      setState(() {
        _savedStats = stats;
        _newBest = session.score > 0 && stats.bestScore == session.score;
      });
    } catch (_) {
      // 記録失敗はラッシュ結果の表示を妨げない
    }
  }

  String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tsumeRushTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: session == null
            ? _buildIntro(l10n)
            : session.isFinished
                ? _buildResult(l10n, session)
                : _buildRunning(l10n, session),
      ),
    );
  }

  Widget _buildIntro(AppLocalizations l10n) => Column(
        children: [
          Text(l10n.tsumeRushRules(
              widget.duration.inMinutes, TsumeRushSession.defaultLives)),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('tsume_rush_start'),
            onPressed: _start,
            child: Text(l10n.tsumeRushStart),
          ),
        ],
      );

  Widget _buildRunning(AppLocalizations l10n, TsumeRushSession session) {
    final puzzle = session.current!;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text('⏱ ${_clock(_remaining)}', key: const Key('tsume_rush_clock')),
            Text(l10n.tsumeRushScore(session.score),
                key: const Key('tsume_rush_score')),
            Text(l10n.tsumeRushStreak(session.streak)),
            Text('♥' * session.lives, key: const Key('tsume_rush_lives')),
          ],
        ),
        const SizedBox(height: 8),
        Text('${puzzle.title ?? ''}（${l10n.tsumeMateInOne}）'),
        if (_lastAnswer != null)
          Text(
            _lastAnswer == TsumeAnswer.correct
                ? l10n.tsumeCorrect
                : l10n.tsumeWrong,
            style: TextStyle(
              color: _lastAnswer == TsumeAnswer.correct
                  ? Colors.green
                  : Colors.red,
            ),
          ),
        const SizedBox(height: 8),
        TsumeBoard(
          key: ValueKey(puzzle.id),
          position: puzzle.position,
          onMove: _onMove,
        ),
      ],
    );
  }

  Widget _buildResult(AppLocalizations l10n, TsumeRushSession session) {
    final reason = switch (session.endReason!) {
      TsumeRushEndReason.timeUp => l10n.tsumeRushEndTimeUp,
      TsumeRushEndReason.outOfLives => l10n.tsumeRushEndLives,
      TsumeRushEndReason.allSolved => l10n.tsumeRushEndAll,
    };
    return Column(
      key: const Key('tsume_rush_result'),
      children: [
        Text(reason, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text(l10n.tsumeRushScore(session.score),
            style: Theme.of(context).textTheme.headlineMedium),
        Text(l10n.tsumeRushBestStreakResult(session.bestStreak)),
        if (_newBest) Text(l10n.tsumeRushNewBest),
        if (_savedStats != null)
          Text(l10n.tsumeRushBestValue(
              _savedStats!.bestScore, _savedStats!.bestStreak)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _start, child: Text(l10n.tsumeRushAgain)),
      ],
    );
  }
}
