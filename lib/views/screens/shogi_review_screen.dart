import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../viewmodels/index.dart';

/// 終局後の感想戦。komovia_core PR #7の共有`ReviewEngine`
/// （komovia_chessの実装済みGameAnalysis/MoveQualityを一般化したもの）を
/// `runShogiReviewProvider`経由で呼び出し、1手ごとの評価とaccuracyを
/// 表示する — Chess版GameReviewScreenの将棋版だが、エンジンが
/// `ShogiEngine`であることを除けば中身はkomovia_core任せ。
///
/// 検討には1手ごとにエンジン呼び出しが要るため数秒かかる — ボタンを
/// 押した時点で非同期に実行し、進捗を表示する（画面を開いた瞬間に
/// 自動実行しないのは、対局直後に不要なCPU負荷をかけないため）。
class ShogiReviewScreen extends ConsumerStatefulWidget {
  const ShogiReviewScreen({super.key});

  @override
  ConsumerState<ShogiReviewScreen> createState() => _ShogiReviewScreenState();
}

class _ShogiReviewScreenState extends ConsumerState<ShogiReviewScreen> {
  Future<GameAnalysis>? _analysisFuture;
  int _done = 0;
  int _total = 0;

  void _startReview() {
    setState(() {
      _done = 0;
      _total = 0;
      _analysisFuture = ref.read(runShogiReviewProvider)(
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _done = done;
            _total = total;
          });
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('感想戦')),
      body: _analysisFuture == null
          ? Center(
              child: FilledButton.icon(
                onPressed: _startReview,
                icon: const Icon(Icons.insights),
                label: const Text('検討する'),
              ),
            )
          : FutureBuilder<GameAnalysis>(
              future: _analysisFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _total == 0 ? '検討中…' : '検討中… ($_done / $_total)',
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(child: Text('検討に失敗しました: ${snapshot.error}'));
                }
                final analysis = snapshot.data!;
                return _AnalysisBody(analysis: analysis);
              },
            ),
    );
  }
}

class _AnalysisBody extends StatelessWidget {
  const _AnalysisBody({required this.analysis});

  final GameAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _AccuracyCard(
                label: '先手',
                accuracy: analysis.accuracyFor(Side.first),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AccuracyCard(
                label: '後手',
                accuracy: analysis.accuracyFor(Side.second),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('一手ごとの評価', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final move in analysis.moves) _MoveTile(move: move),
      ],
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard({required this.label, required this.accuracy});

  final String label;
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label),
            const SizedBox(height: 4),
            Text(
              '${accuracy.toStringAsFixed(0)}%',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text('正確度', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({required this.move});

  final MoveAnalysis move;

  static const _labels = {
    MoveQuality.best: ('最善', Colors.green),
    MoveQuality.good: ('良い手', Colors.lightGreen),
    MoveQuality.inaccuracy: ('不正確', Colors.orange),
    MoveQuality.mistake: ('悪手', Colors.deepOrange),
    MoveQuality.blunder: ('大悪手', Colors.red),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labels[move.quality]!;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: color,
        child: Text(
          '${move.moveIndex}',
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ),
      title: Text(move.side == Side.first ? '先手' : '後手'),
      trailing: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.15),
        side: BorderSide(color: color),
      ),
    );
  }
}
