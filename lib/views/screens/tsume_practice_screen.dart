import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/tsume/tsume_logic.dart';
import 'package:komovia_shogi/src/tsume/tsume_problems.dart';

import '../../l10n/app_localizations.dart';
import '../widgets/tsume_board.dart';

/// 詰将棋を1問ずつ解く画面（時間制限なし）。不正解ならやり直し、
/// 正解したら次の問題へ。ラッシュモードの土台となる単問の解答体験。
class TsumePracticeScreen extends StatefulWidget {
  const TsumePracticeScreen({super.key, this.puzzles});

  /// テスト用に問題を差し替えられる（既定は内蔵の詰将棋）。
  final List<Puzzle<ShogiPosition>>? puzzles;

  @override
  State<TsumePracticeScreen> createState() => _TsumePracticeScreenState();
}

class _TsumePracticeScreenState extends State<TsumePracticeScreen> {
  late final List<Puzzle<ShogiPosition>> _puzzles =
      widget.puzzles ?? builtInTsumeProblems();
  final _game = ShogiGame();
  int _index = 0;
  late ShogiPosition _position = _puzzles.first.position;
  Move? _lastMove;
  bool? _solved; // null = 解答中

  void _onMove(Move move) {
    final puzzle = _puzzles[_index];
    final ok = TsumeJudge.isMatingMove(puzzle.position, move);
    setState(() {
      _position = _game.apply(puzzle.position, move);
      _lastMove = move;
      _solved = ok;
    });
  }

  void _retry() => setState(() {
        _position = _puzzles[_index].position;
        _lastMove = null;
        _solved = null;
      });

  void _next() => setState(() {
        _index = (_index + 1) % _puzzles.length;
        _position = _puzzles[_index].position;
        _lastMove = null;
        _solved = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final puzzle = _puzzles[_index];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tsumePracticeTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              l10n.tsumeProgress(_index + 1, _puzzles.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              '${puzzle.title ?? ''}（${l10n.tsumeMateInOne}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TsumeBoard(
              position: _position,
              lastMove: _lastMove,
              enabled: _solved == null,
              onMove: _onMove,
            ),
            const SizedBox(height: 12),
            if (_solved == true) ...[
              Text(l10n.tsumeCorrect,
                  key: const Key('tsume_result_correct'),
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              FilledButton(onPressed: _next, child: Text(l10n.tsumeNext)),
            ],
            if (_solved == false) ...[
              Text(l10n.tsumeWrong,
                  key: const Key('tsume_result_wrong'),
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: _retry, child: Text(l10n.tsumeRetry)),
                TextButton(onPressed: _next, child: Text(l10n.tsumeSkip)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
