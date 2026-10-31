import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../services/ai_review_quota_service.dart';
import '../../services/purchase_service.dart';
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

  /// 拒否された理由（許可されていればnull）。
  AiReviewAccess? _denied;
  bool _purchasing = false;

  Future<void> _startReview() async {
    final access = await ref.read(consumeAiReviewQuotaProvider)();
    if (!mounted) return;
    if (access != AiReviewAccess.allowed) {
      setState(() => _denied = access);
      return;
    }
    _denied = null;
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

  /// 無料枠を使い切ったときの案内。AI分析プランをその場で購入できる。
  Widget _buildUpsell(AppLocalizations l10n) {
    final product =
        ref.watch(aiAnalysisPlanProductProvider(AiAnalysisPlan.monthly)).value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.aiReviewDailyLimitMessage(AiReviewQuotaService.dailyLimit),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(l10n.aiAnalysisPlanUpsellDescription,
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('ai-analysis-plan-upsell-button'),
              onPressed: _purchasing ? null : _purchaseAiAnalysisPlan,
              icon: const Icon(Icons.auto_awesome),
              label: Text(l10n.aiAnalysisPlanSubscribeButton(
                  product?.price ?? l10n.aiAnalysisPlanFallbackPrice)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseAiAnalysisPlan() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _purchasing = true);
    try {
      await ref.read(purchaseAiAnalysisPlanProvider)(AiAnalysisPlan.monthly);
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.purchaseSuccessMessage)));
      if (!mounted) return;
      setState(() => _denied = null);
      await _startReview();
    } on PurchaseCanceledException {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.purchaseCanceledMessage)));
    } on PurchaseUnavailableException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.purchaseFailedMessage('$e'))));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: _denied == AiReviewAccess.signInRequired
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.aiReviewSignInRequiredMessage,
                    textAlign: TextAlign.center),
              ),
            )
          : _denied == AiReviewAccess.limitReached
          ? _buildUpsell(l10n)
          : _analysisFuture == null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _startReview,
                    icon: const Icon(Icons.insights),
                    label: Text(l10n.startReviewButton),
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
                                _total == 0
                                    ? l10n.reviewingMessage
                                    : l10n.reviewingProgressMessage(
                                        _done, _total),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child:
                            Text(l10n.reviewFailedMessage('${snapshot.error}')),
                      );
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
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _AccuracyCard(
                label: l10n.senteLabel,
                accuracy: analysis.accuracyFor(Side.first),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AccuracyCard(
                label: l10n.goteLabel,
                accuracy: analysis.accuracyFor(Side.second),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.moveByMoveLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
            Text(AppLocalizations.of(context)!.accuracyLabel,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MoveTile extends StatelessWidget {
  const _MoveTile({required this.move});

  final MoveAnalysis move;

  static const _colors = {
    MoveQuality.best: Colors.green,
    MoveQuality.good: Colors.lightGreen,
    MoveQuality.inaccuracy: Colors.orange,
    MoveQuality.mistake: Colors.deepOrange,
    MoveQuality.blunder: Colors.red,
  };

  String _labelFor(AppLocalizations l10n, MoveQuality quality) {
    switch (quality) {
      case MoveQuality.best:
        return l10n.moveQualityBest;
      case MoveQuality.good:
        return l10n.moveQualityGood;
      case MoveQuality.inaccuracy:
        return l10n.moveQualityInaccuracy;
      case MoveQuality.mistake:
        return l10n.moveQualityMistake;
      case MoveQuality.blunder:
        return l10n.moveQualityBlunder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _colors[move.quality]!;
    final label = _labelFor(l10n, move.quality);
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
      title: Text(move.side == Side.first ? l10n.senteLabel : l10n.goteLabel),
      trailing: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: color.withValues(alpha: 0.15),
        side: BorderSide(color: color),
      ),
    );
  }
}
