import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import '../../l10n/app_localizations.dart';
import '../../viewmodels/index.dart';

/// この画面の3ステップ。`komovia_core`の`OnboardingStep`/`OnboardingProgress`
/// 上に構築する — フロー進行と「実際にやるまで次へ進めない」というゲーム
/// 非依存のロジックは`komovia_core`側に切り出し済み（komovia_shogiが最初の
/// 実装、他の3アプリはこのパターンを後続で流用する想定）。このファイルの
/// 責務は、ステップを実際のウィジェットに描画することと、最後のステップの
/// 本物のインタラクティブデモ（銀で歩を取る）だけ。
List<OnboardingStep> _buildSteps(AppLocalizations l10n) => [
      OnboardingStep(
        id: 'how-to-move',
        title: l10n.onboardingStep1Title,
        body: l10n.onboardingStep1Body,
        icon: 'touch_app',
      ),
      OnboardingStep(
        id: 'win-condition',
        title: l10n.onboardingStep2Title,
        body: l10n.onboardingStep2Body,
        icon: 'emoji_events_outlined',
      ),
      OnboardingStep(
        id: 'capture-demo',
        title: l10n.onboardingStep3Title,
        body: l10n.onboardingStep3Body,
        requiresExplicitCompletion: true,
      ),
    ];

/// `OnboardingStep.icon`（Flutter非依存の文字列識別子）を実際の`IconData`
/// に解決する — この変換自体がアプリ固有の責務（komovia_coreはFlutterの
/// 型を一切知らない）。
IconData? _iconFor(String? name) {
  switch (name) {
    case 'touch_app':
      return Icons.touch_app;
    case 'emoji_events_outlined':
      return Icons.emoji_events_outlined;
    default:
      return null;
  }
}

/// 初回起動時だけ表示する、最短で「駒を取る」体験までたどり着く一回限りの
/// ルール説明。3ステップ構成（駒の動かし方→勝敗条件→実際に駒を取ってみる）で、
/// 最後のステップだけが実際にタップできるミニ盤になっている。
///
/// いつでも見返せる参照用のルール説明ではない（そちらは別途作る想定） —
/// これは「最初の1回だけ」のオンボーディングで、[completeOnboardingProvider]
/// を呼んだ後は二度と表示されない。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  /// オンボーディング完了後（「はじめる」タップ後）に呼ばれるコールバック。
  final VoidCallback onFinished;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

// `OnboardingProgress`'s flow logic (advance/canAdvance/markStepCompleted)
// only cares about each step's `id`/`requiresExplicitCompletion`, never
// its title/body — those are rendered straight from the localized list
// `_buildSteps` returns inside `build()`. This placeholder list exists
// only so `OnboardingProgress` can be constructed before a `BuildContext`
// (and therefore `AppLocalizations`) is available.
const _stepIdsForProgress = [
  OnboardingStep(id: 'how-to-move', title: '', body: ''),
  OnboardingStep(id: 'win-condition', title: '', body: ''),
  OnboardingStep(
    id: 'capture-demo',
    title: '',
    body: '',
    requiresExplicitCompletion: true,
  ),
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  OnboardingProgress _progress =
      const OnboardingProgress(steps: _stepIdsForProgress);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    setState(() => _progress = _progress.advance());
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _onDemoCaptured() {
    setState(() => _progress = _progress.markStepCompleted('capture-demo'));
  }

  Future<void> _finish() async {
    // advance()はここでは記録としての意味合い（isFlowCompleteを立てる）
    // のみ — 画面遷移は直接onFinishedで行う。
    setState(() => _progress = _progress.advance());
    await ref.read(completeOnboardingProvider)();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = _buildSteps(l10n);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RulesCard(step: steps[0], onNext: _next),
                  _RulesCard(step: steps[1], onNext: _next),
                  _CaptureDemoCard(
                    step: steps[2],
                    captured: _progress.completedStepIds
                        .contains('capture-demo'),
                    onCaptured: _onDemoCaptured,
                    onFinished: _finish,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  steps.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _progress.currentIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.step, required this.onNext});

  final OnboardingStep step;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(step.icon);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
            ],
            Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              step.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onNext,
              child: Text(AppLocalizations.of(context)!.nextButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// オンボーディング最後のページ: 実際にタップして1枚取ってみる体験。
/// `onboardingDemoPosition()`は「銀が歩をすぐ前で取れる」だけの最小構成 —
/// 1タップで駒を選び、もう1タップで取る、という最短の「あっ」体験にする。
///
/// 捕獲が成立すると[onCaptured]（`OnboardingProgress.markStepCompleted`
/// を呼ぶ）を一度だけ呼び、それによって親の`FilledButton`（「はじめる」）
/// が有効になる — ボタンの有効/無効自体はこのウィジェットではなく親が
/// `OnboardingProgress.canAdvance`相当の判断で決める。
class _CaptureDemoCard extends StatefulWidget {
  const _CaptureDemoCard({
    required this.step,
    required this.captured,
    required this.onCaptured,
    required this.onFinished,
  });

  final OnboardingStep step;
  final bool captured;
  final VoidCallback onCaptured;
  final Future<void> Function() onFinished;

  @override
  State<_CaptureDemoCard> createState() => _CaptureDemoCardState();
}

class _CaptureDemoCardState extends State<_CaptureDemoCard> {
  final _renderer = ShogiBoardRenderer();
  final _game = ShogiGame();
  late ShogiPosition _position = onboardingDemoPosition();
  Square? _selected;
  List<Square> _hints = const [];

  void _onTapSquare(Square square) {
    if (widget.captured) return;
    if (_selected == null) {
      final legal = _game
          .legalMoves(_position)
          .whereType<BoardMove>()
          .where((m) => m.from == square)
          .toList();
      if (legal.isNotEmpty) {
        setState(() {
          _selected = square;
          _hints = legal.map((m) => m.to).toList();
        });
      }
      return;
    }
    if (square == onboardingDemoCaptureMove.to) {
      setState(() {
        _position = _game.apply(_position, onboardingDemoCaptureMove);
        _selected = null;
        _hints = const [];
      });
      widget.onCaptured();
    } else {
      setState(() {
        _selected = null;
        _hints = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.captured ? l10n.capturedMessage : widget.step.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = constraints.maxWidth.clamp(0, 320).toDouble();
                return GestureDetector(
                  key: const Key('onboarding_board_gesture_detector'),
                  onTapUp: (details) {
                    final square = _renderer.squareAt(
                      BoardOffset(
                        details.localPosition.dx,
                        details.localPosition.dy,
                      ),
                      BoardSize(boardSize, boardSize),
                      _position,
                    );
                    if (square != null) _onTapSquare(square);
                  },
                  child: SizedBox(
                    // 高さは固定しない: 持ち駒バーが追加されるとoverflow
                    // するため（main.dartのShogiGameScreenと同じ理由、
                    // 同じ修正）。
                    width: boardSize,
                    child: _renderer.build(
                      _position,
                      hints: _hints,
                      selected: _selected,
                      textured: true,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (widget.captured)
              Text(
                l10n.capturedExplanationMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.captured ? widget.onFinished : null,
              child: Text(l10n.beginButton),
            ),
          ],
        ),
      ),
    );
  }
}
