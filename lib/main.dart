import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_options.dart';
import 'viewmodels/index.dart';
import 'views/screens/home_screen.dart';
import 'views/screens/onboarding_screen.dart';
import 'views/screens/shogi_review_screen.dart';

/// komovia_shogi: the shogi AI対局 demo screen (`ShogiGameScreen`, exercising
/// `ShogiGame`/`ShogiEngine`/`ShogiBoardRenderer` end to end) plus a social
/// layer (friends/notifications/messages/leaderboard/tournaments) built on
/// komovia_core's shared models, reached from a `HomeScreen` hub.
///
/// Firebase is initialized with placeholder config (`firebase_options.dart`)
/// until `flutterfire configure` is run against a real project.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Placeholder Firebase config won't actually initialize against a real
    // backend; swallow so the shogi demo screen still runs standalone.
  }
  runApp(const ProviderScope(child: KomoviaShogiApp()));
}

class KomoviaShogiApp extends StatelessWidget {
  const KomoviaShogiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Komovia Shogi',
      theme:
          ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown)),
      home: const _RootScreen(),
    );
  }
}

/// Signs the user in anonymously (if not already) so the social features
/// have a stable uid, then shows [HomeScreen].
class _RootScreen extends ConsumerStatefulWidget {
  const _RootScreen();

  @override
  ConsumerState<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<_RootScreen> {
  @override
  void initState() {
    super.initState();
    _ensureSignedIn();
  }

  Future<void> _ensureSignedIn() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await ref.read(authServiceProvider).signInAnonymously();
      }
    } catch (_) {
      // No real Firebase project configured yet — social screens will show
      // their signed-out state instead of crashing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

    return hasCompletedOnboarding.when(
      data: (completed) => completed
          ? HomeScreen(onPlayShogi: () => _pushGame(context))
          : OnboardingScreen(onFinished: () => _pushGame(context)),
      // ローディング中は空白のまま待つ（スプラッシュ代わり） — 判定が
      // 一瞬で終わるローカルSharedPreferences読み込みなので、専用の
      // スプラッシュ画面を出すほどの長さにはならない。
      loading: () => const Scaffold(body: SizedBox.shrink()),
      // ローカル読み込みが万一失敗しても、オンボーディング未完了として
      // 安全側に倒す（ホーム画面に進めなくなるよりはまし）。
      error: (_, __) => OnboardingScreen(onFinished: () => _pushGame(context)),
    );
  }

  /// `_RootScreen`自体は常にナビゲーションスタックの一番下（唯一のroute）
  /// にとどまる — `OnboardingScreen`/`HomeScreen`はpushされた別routeでは
  /// なく、このウィジェットのbuild()が条件分岐で出し分けているだけなので、
  /// ここでの`push`は常に素直に「その上にもう1枚積む」だけでよい
  /// （オンボーディング直後でも、戻るボタンを押せばその時点で既に
  /// `completeOnboardingProvider`済みの`_RootScreen`＝HomeScreenに戻る）。
  void _pushGame(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShogiGameScreen()),
    );
  }
}

class ShogiGameScreen extends ConsumerStatefulWidget {
  const ShogiGameScreen({super.key});

  @override
  ConsumerState<ShogiGameScreen> createState() => _ShogiGameScreenState();
}

class _ShogiGameScreenState extends ConsumerState<ShogiGameScreen> {
  final _renderer = ShogiBoardRenderer();

  Square? _selected;
  List<Square> _hints = const [];
  bool _aiThinking = false;
  String _status = '';

  // 「待った」用の局面履歴。手を打つたびに「打つ前」の局面を積んでおき、
  // undoではその局面に直接戻す（chess/goのように手リストから再生するの
  // ではなく、局面そのものを保存している — ShogiPositionは不変なので
  // 安全に共有できる）。画面を離れると失われる対話専用の状態なので、
  // 再開・保存の対象であるshogi_game_provider.dartの状態とは別に、
  // ここではウィジェットローカルなまま保持している。
  final List<ShogiPosition> _positionHistory = [];

  bool get _canUndo => _positionHistory.isNotEmpty && !_aiThinking;

  bool _hintLoading = false;

  ShogiGame get _game => ref.read(shogiGameProvider);
  ShogiEngine get _engine => ref.read(shogiEngineProvider);
  ShogiPosition get _position => ref.read(shogiPositionProvider);
  GameResult get _result => ref.read(shogiResultProvider);
  ShogiDifficulty get _difficulty => ref.read(shogiDifficultyProvider);
  Move? get _lastMove => ref.read(shogiLastMoveProvider);
  List<Object> get _historyKeys => ref.read(shogiPositionHistoryKeysProvider);

  bool get _canRequestHint =>
      !_aiThinking &&
      !_hintLoading &&
      _result.isOngoing &&
      _position.sideToMove == _humanSide;

  @override
  void initState() {
    super.initState();
    // 中断・再開機能: 既に対局が進行中（再開された、または同一セッション内
    // で前回から続いている）場合は、難易度選択ダイアログを出さずそのまま
    // 続きの盤面を表示する。
    if (ref.read(isShogiGameActiveProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pickDifficulty(restartGame: false);
    });
  }

  /// Shows the AI-strength picker. Called once on first load (before the
  /// very first game, so the player always chooses before playing rather
  /// than discovering the fixed level by trial and error) and again from
  /// the app bar's tune icon at any point - picking there restarts the
  /// game with the newly-selected level, since mid-game strength changes
  /// would be confusing.
  Future<void> _pickDifficulty({bool restartGame = true}) async {
    var quick = ref.read(shogiQuickGameProvider);
    final selected = await showDialog<ShogiDifficulty>(
      context: context,
      barrierDismissible: !restartGame,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SimpleDialog(
          title: const Text('AIの強さを選んでください'),
          children: [
            ...ShogiDifficulty.values.map(
              (d) => SimpleDialogOption(
                onPressed: () {
                  ref.read(shogiQuickGameProvider.notifier).state = quick;
                  Navigator.of(context).pop(d);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(d.description, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            CheckboxListTile(
              value: quick,
              onChanged: (value) =>
                  setDialogState(() => quick = value ?? false),
              title: const Text('クイック対局'),
              subtitle: const Text('AIの考慮時間を短くし、短時間で一局を終えられるようにします。'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    ref.read(shogiDifficultyProvider.notifier).state = selected;
    if (restartGame) _newGame();
  }

  Side get _humanSide => Side.first;

  void _onTapSquare(Square square) {
    if (_aiThinking || _position.sideToMove != _humanSide) return;

    final legal = _game.legalMoves(_position, historyKeys: _historyKeys);
    if (_selected == null) {
      final movesFromHere =
          legal.whereType<BoardMove>().where((m) => m.from == square).toList();
      if (movesFromHere.isNotEmpty) {
        setState(() {
          _selected = square;
          _hints = movesFromHere.map((m) => m.to).toList();
        });
      }
      return;
    }

    // Evaluated eagerly (not left as a lazy Iterable) because its
    // predicate closes over `_selected`, which the setState below
    // mutates — a lazy `.where()` re-evaluated after that setState would
    // always see `_selected == null` and find no match.
    final matches = legal
        .whereType<BoardMove>()
        .where((m) => m.from == _selected && m.to == square)
        .toList();
    setState(() {
      _selected = null;
      _hints = const [];
    });
    if (matches.isNotEmpty) {
      _applyMove(matches.first);
    }
  }

  void _applyMove(Move move) {
    final before = _position;
    ref.read(applyShogiMoveProvider)(move);
    unawaited(ref.read(persistActiveShogiGameProvider)());
    setState(() => _positionHistory.add(before));
    _checkResultOrLetAiMove();
  }

  /// 直前の自分の手（とそれに対するAIの応手があれば、それも）を取り消す。
  /// 人間の手番に戻るまで局面履歴を遡る — 通常は2手（自分の手+AIの応手）
  /// だが、その手で終局していた場合は1手だけ遡れば人間の手番に戻る。
  /// 棋譜(shogiMoveHistoryProvider)も、巻き戻した手数ぶんだけ末尾を
  /// 切り詰める — 保存対象の棋譜が実際の盤面より先に進んでしまわないように。
  void _undo() {
    if (!_canUndo) return;
    var position = _position;
    var moveCount = ref.read(shogiMoveCountProvider);
    var history = ref.read(shogiMoveHistoryProvider);
    var historyKeys = ref.read(shogiPositionHistoryKeysProvider);
    while (_positionHistory.isNotEmpty) {
      position = _positionHistory.removeLast();
      moveCount--;
      if (history.isNotEmpty) {
        history = history.sublist(0, history.length - 1);
      }
      // historyKeysは常に「初期局面+これまでの着手数」ぶんの長さを保つ
      // （historyKeys[0]が初期局面）ので、1手戻すたびに末尾を1つ切り詰める。
      if (historyKeys.length > 1) {
        historyKeys = historyKeys.sublist(0, historyKeys.length - 1);
      }
      if (position.sideToMove == _humanSide) break;
    }
    ref.read(shogiPositionProvider.notifier).state = position;
    ref.read(shogiMoveCountProvider.notifier).state = moveCount;
    ref.read(shogiMoveHistoryProvider.notifier).state = history;
    ref.read(shogiPositionHistoryKeysProvider.notifier).state = historyKeys;
    ref.read(shogiLastMoveProvider.notifier).state = null;
    ref.read(shogiResultProvider.notifier).state =
        _game.result(position, historyKeys: historyKeys);
    setState(() {
      _selected = null;
      _hints = const [];
      _status = '';
    });
    unawaited(ref.read(persistActiveShogiGameProvider)());
  }

  /// 次の一手のヒントを示す。現在選択中の差し手の強さ(_difficulty)とは
  /// 独立に、常に`ShogiDifficulty.hard`相当の深さで読んで提案する —
  /// 弱いAIを選んでいても、ヒント自体は手加減しない本気の一手にする。
  /// 提案手は通常の「駒を選択して行き先をハイライト」と同じ見た目
  /// （_selected/_hints）で示すため、そのままタップして着手できる。
  Future<void> _showHint() async {
    if (!_canRequestHint) return;
    setState(() => _hintLoading = true);
    final move =
        await _engine.bestMove(_position, level: ShogiDifficulty.hard.depth);
    if (!mounted) return;
    setState(() {
      _hintLoading = false;
      if (move is BoardMove) {
        _selected = move.from;
        _hints = [move.to];
      }
    });
  }

  Future<void> _checkResultOrLetAiMove() async {
    final result = _game.result(_position, historyKeys: _historyKeys);
    if (!result.isOngoing) {
      ref.read(shogiResultProvider.notifier).state = result;
      setState(() => _status = _describeResult(result));
      unawaited(ref.read(updateShogiRatingAfterGameProvider)(result));
      ref.read(clearActiveShogiGameProvider)();
      return;
    }
    if (_position.sideToMove == _humanSide) return;

    setState(() {
      _aiThinking = true;
      _status = 'AI考慮中…';
    });
    final quick = ref.read(shogiQuickGameProvider);
    final move = await _engine.bestMove(
      _position,
      level: _difficulty.depth,
      timeBudget: quick ? _difficulty.quickTimeBudget : null,
    );
    if (!mounted) return;
    setState(() {
      _aiThinking = false;
      _status = '';
    });
    if (move != null) _applyMove(move);
  }

  String _describeResult(GameResult result) {
    switch (result.kind) {
      case ResultKind.win:
        final winner = result.winner == Side.first ? '先手' : '後手';
        final suffix = result.reason == WinReason.resignation ? '（投了）' : '';
        return '$winner勝ち$suffix';
      case ResultKind.draw:
        return '引き分け';
      case ResultKind.ongoing:
        return '';
    }
  }

  bool get _canResign => !_aiThinking && _result.isOngoing;

  /// 投了する。[_game.apply]はResignMoveの合法性チェックを行わない
  /// （komovia_coreのドキュメント通り、手番に関係なく常に可能）ので、
  /// AIの応手が進行中（_aiThinking）の間はボタン自体を無効化し、
  /// 非同期のAI応手と投了が競合して結果を上書きし合わないようにする。
  Future<void> _confirmResign() async {
    if (!_canResign) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投了しますか？'),
        content: const Text('投了すると、この対局はあなたの負けとして終了します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('投了する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canResign) return;
    final newPosition = _game.apply(_position, ResignMove(_humanSide));
    final result = _game.result(newPosition);
    ref.read(shogiPositionProvider.notifier).state = newPosition;
    ref.read(shogiResultProvider.notifier).state = result;
    setState(() {
      _status = _describeResult(result);
      _selected = null;
      _hints = const [];
    });
    unawaited(ref.read(updateShogiRatingAfterGameProvider)(result));
    ref.read(clearActiveShogiGameProvider)();
  }

  void _newGame() {
    setState(() {
      _selected = null;
      _hints = const [];
      _status = '';
      _positionHistory.clear();
    });
    ref.read(startShogiGameProvider)();
    unawaited(ref.read(persistActiveShogiGameProvider)());
  }

  /// Shares the just-finished game's result as an SNS-ready caption via
  /// the OS share sheet, built through komovia_core's ShareableMoment so
  /// it matches the same caption shape the other Komovia apps use.
  Future<void> _shareResult() async {
    final won = _result.winner == _humanSide;
    final isDraw = _result.kind == ResultKind.draw;
    final headline = switch ((won, isDraw)) {
      (_, true) => '引き分けでした！',
      (true, false) => '勝ちました！',
      (false, false) => '惜しくも敗戦…',
    };

    await Share.share(
      buildShareCaption(
        ShareableMoment(
          appName: 'Komovia将棋',
          headline: headline,
          statLines: ['手数: ${ref.read(shogiMoveCountProvider)}手'],
          hashtag: '#Komovia将棋',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komovia Shogi'),
        actions: [
          IconButton(
            onPressed: _pickDifficulty,
            icon: const Icon(Icons.tune),
            tooltip: 'AIの強さ（現在: ${_difficulty.displayName}'
                '${ref.watch(shogiQuickGameProvider) ? "・クイック対局" : ""}）',
          ),
          IconButton(
            onPressed: _canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
            tooltip: '待った',
          ),
          IconButton(
            onPressed: _canRequestHint ? _showHint : null,
            icon: _hintLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lightbulb_outline),
            tooltip: 'ヒント',
          ),
          IconButton(
            onPressed: _canResign ? _confirmResign : null,
            icon: const Icon(Icons.flag),
            tooltip: '投了',
          ),
          IconButton(onPressed: _newGame, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        // SingleChildScrollView + mainAxisSize.min: 持ち駒バーが増えて
        // 盤の実高さが伸びても（多種類の持ち駒がWrapで2段になった場合
        // など）、画面の高さを超えた分はスクロールで吸収する（固定高の
        // 親に収めようとするとoverflowし得るため、根本的にスクロール
        // 可能にしておく）。
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _status.isEmpty ? '先手（あなた）の番です' : _status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!_result.isOngoing) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _shareResult,
                        icon: const Icon(Icons.share),
                        label: const Text('SNSでシェア'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ShogiReviewScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.insights),
                        label: const Text('感想戦'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize =
                          constraints.maxWidth.clamp(0, 400).toDouble();
                      return GestureDetector(
                        key: const Key('shogi_board_gesture_detector'),
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
                          // 高さは固定しない: 持ち駒がある間は`MiniBoardWidget`
                          // が盤の上下に持ち駒バーを足すため、盤サイズと同じ
                          // 固定高にすると実戦で駒を取った瞬間に確実に
                          // RenderFlexオーバーフローする（本バグはオンボー
                          // ディング画面の実装中に発見・修正）。
                          width: boardSize,
                          child: _renderer.build(
                            _position,
                            lastMove: _lastMove,
                            hints: _hints,
                            selected: _selected,
                            textured: true,
                            advantageRatio:
                                ShogiBoardRenderer.materialAdvantageRatio(
                                    _position),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
