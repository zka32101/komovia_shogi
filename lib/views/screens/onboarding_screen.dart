import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import '../../viewmodels/index.dart';

/// 初回起動時だけ表示する、最短で「駒を取る」体験までたどり着く一回限りの
/// ルール説明。3ページ構成（駒の動かし方→勝敗条件→実際に駒を取ってみる）で、
/// 最後のページだけが実際にタップできるミニ盤になっている。
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

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(completeOnboardingProvider)();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _RulesCard(
                    icon: Icons.touch_app,
                    title: '駒の動かし方',
                    body: '駒をタップすると、動かせるマスがハイライトされます。'
                        'ハイライトされたマスをタップすれば、そこへ指せます。',
                    onNext: _next,
                  ),
                  _RulesCard(
                    icon: Icons.emoji_events_outlined,
                    title: '勝敗',
                    body: '相手の「王将」を詰ませた方の勝ちです。'
                        '取った相手の駒は「持ち駒」になり、後で自分の駒として盤に打てます。',
                    onNext: _next,
                  ),
                  _CaptureDemoCard(onFinished: _finish),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page
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
  const _RulesCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onNext,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onNext, child: const Text('次へ')),
          ],
        ),
      ),
    );
  }
}

/// オンボーディング最後のページ: 実際にタップして1枚取ってみる体験。
/// `onboardingDemoPosition()`は「銀が歩をすぐ前で取れる」だけの最小構成 —
/// 1タップで駒を選び、もう1タップで取る、という最短の「あっ」体験にする。
class _CaptureDemoCard extends StatefulWidget {
  const _CaptureDemoCard({required this.onFinished});

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
  bool _captured = false;

  void _onTapSquare(Square square) {
    if (_captured) return;
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
        _captured = true;
      });
    } else {
      setState(() {
        _selected = null;
        _hints = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _captured ? 'やった、1枚取れました！' : '銀をタップして、歩を取ってみましょう',
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
            if (_captured)
              Text(
                '取った駒は自分の「持ち駒」になります。後で盤の空いているマスに打てます。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _captured ? widget.onFinished : null,
              child: const Text('はじめる'),
            ),
          ],
        ),
      ),
    );
  }
}
