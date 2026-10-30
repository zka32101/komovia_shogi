import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/event_config_service.dart';
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
  // 期間限定イベントの開催期間（Remote Config）。キャッシュ値を有効化し、
  // 最新値の取得はバックグラウンド。失敗しても全イベント非表示で起動する。
  final eventConfig = EventConfigService();
  await eventConfig.initialize();
  runApp(ProviderScope(
    overrides: [eventConfigServiceProvider.overrideWithValue(eventConfig)],
    child: const KomoviaShogiApp(),
  ));
}

class KomoviaShogiApp extends StatelessWidget {
  const KomoviaShogiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Komovia Shogi',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

  // 「正確さ訴求」: 終局後、感想戦ボタンを押す前から「あなたの正確度」を
  // 自動で計算して表示する — komovia_coreのReviewEngine(ChessAnalysisService
  // を一般化したもの)がすでに持っているaccuracyFor(Side)を、感想戦という
  // 追加の一手間の裏に隠したままにせず、対局直後の一番目立つ場所で見せる
  // ことで、「AIが本当にコーチしてくれる」という価値を具体的な数字として
  // 即座に体感できるようにする。
  GameAnalysis? _accuracyAnalysis;
  bool _accuracyLoading = false;

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
    unawaited(ref.read(loadShowAttackMapPreferenceProvider)());
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
  String _difficultyName(AppLocalizations l10n, ShogiDifficulty d) {
    switch (d) {
      case ShogiDifficulty.beginner:
        return l10n.difficultyBeginnerName;
      case ShogiDifficulty.easy:
        return l10n.difficultyEasyName;
      case ShogiDifficulty.medium:
        return l10n.difficultyMediumName;
      case ShogiDifficulty.hard:
        return l10n.difficultyHardName;
    }
  }

  String _difficultyDescription(AppLocalizations l10n, ShogiDifficulty d) {
    switch (d) {
      case ShogiDifficulty.beginner:
        return l10n.difficultyBeginnerDescription;
      case ShogiDifficulty.easy:
        return l10n.difficultyEasyDescription;
      case ShogiDifficulty.medium:
        return l10n.difficultyMediumDescription;
      case ShogiDifficulty.hard:
        return l10n.difficultyHardDescription;
    }
  }

  Future<void> _pickDifficulty({bool restartGame = true}) async {
    final l10n = AppLocalizations.of(context)!;
    var quick = ref.read(shogiQuickGameProvider);
    final selected = await showDialog<ShogiDifficulty>(
      context: context,
      barrierDismissible: !restartGame,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => SimpleDialog(
          title: Text(l10n.chooseAiStrengthTitle),
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
                        _difficultyName(l10n, d),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _difficultyDescription(l10n, d),
                        style: const TextStyle(fontSize: 12),
                      ),
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
              title: Text(l10n.quickGameLabel),
              subtitle: Text(l10n.quickGameDescription),
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
    final l10n = AppLocalizations.of(context)!;
    if (!result.isOngoing) {
      ref.read(shogiResultProvider.notifier).state = result;
      setState(() => _status = _describeResult(l10n, result));
      unawaited(ref.read(updateShogiRatingAfterGameProvider)(result));
      ref.read(clearActiveShogiGameProvider)();
      unawaited(_computeAccuracy());
      return;
    }
    if (_position.sideToMove == _humanSide) return;

    setState(() {
      _aiThinking = true;
      _status = l10n.aiThinkingMessage;
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

  String _describeResult(AppLocalizations l10n, GameResult result) {
    switch (result.kind) {
      case ResultKind.win:
        final winner =
            result.winner == Side.first ? l10n.senteLabel : l10n.goteLabel;
        final suffix =
            result.reason == WinReason.resignation ? l10n.resignationSuffix : '';
        return l10n.winResultMessage(winner, suffix);
      case ResultKind.draw:
        return l10n.drawResultMessage;
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mainResignConfirmTitle),
        content: Text(l10n.mainResignConfirmContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.mainResignCancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.resignButton),
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
      _status = _describeResult(l10n, result);
      _selected = null;
      _hints = const [];
    });
    unawaited(ref.read(updateShogiRatingAfterGameProvider)(result));
    ref.read(clearActiveShogiGameProvider)();
    unawaited(_computeAccuracy());
  }

  /// 終局後に一度だけ呼ばれる。エンジンが1手ごとに評価するため数秒
  /// かかりうるが、対局終了の表示自体をブロックしたくないので
  /// `unawaited`で呼び出し、結果が出たらバッジを差し込む形にしている。
  Future<void> _computeAccuracy() async {
    setState(() => _accuracyLoading = true);
    final analysis = await ref.read(runShogiReviewProvider)();
    if (!mounted) return;
    setState(() {
      _accuracyLoading = false;
      _accuracyAnalysis = analysis;
    });
  }

  void _newGame() {
    setState(() {
      _selected = null;
      _hints = const [];
      _status = '';
      _positionHistory.clear();
      _accuracyAnalysis = null;
      _accuracyLoading = false;
    });
    ref.read(startShogiGameProvider)();
    unawaited(ref.read(persistActiveShogiGameProvider)());
  }

  /// Shares the just-finished game's result as an SNS-ready caption via
  /// the OS share sheet, built through komovia_core's ShareableMoment so
  /// it matches the same caption shape the other Komovia apps use.
  Future<void> _shareResult() async {
    final l10n = AppLocalizations.of(context)!;
    final won = _result.winner == _humanSide;
    final isDraw = _result.kind == ResultKind.draw;
    final headline = switch ((won, isDraw)) {
      (_, true) => l10n.shareDrawHeadline,
      (true, false) => l10n.shareWinHeadline,
      (false, false) => l10n.shareLoseHeadline,
    };

    await Share.share(
      buildShareCaption(
        ShareableMoment(
          appName: l10n.shareAppName,
          headline: headline,
          statLines: [
            l10n.shareMoveCountLine(ref.read(shogiMoveCountProvider)),
          ],
          hashtag: l10n.shareHashtag,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            onPressed: _pickDifficulty,
            icon: const Icon(Icons.tune),
            tooltip: l10n.aiStrengthTooltip(
              _difficultyName(l10n, _difficulty),
              ref.watch(shogiQuickGameProvider) ? l10n.quickGameSuffixLabel : '',
            ),
          ),
          IconButton(
            onPressed: _canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
            tooltip: l10n.undoTooltip,
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
            tooltip: l10n.hintTooltip,
          ),
          IconButton(
            onPressed: _canResign ? _confirmResign : null,
            icon: const Icon(Icons.flag),
            tooltip: l10n.resignTooltip,
          ),
          IconButton(
            onPressed: () => ref.read(toggleShowAttackMapProvider)(),
            icon: Icon(
              Icons.visibility,
              color: ref.watch(showAttackMapProvider)
                  ? Colors.orangeAccent
                  : null,
            ),
            tooltip: ref.watch(showAttackMapProvider)
                ? l10n.hideAttackMapTooltip
                : l10n.showAttackMapTooltip,
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
                  _status.isEmpty ? l10n.yourTurnStatusMessage : _status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!_result.isOngoing) ...[
                  const SizedBox(height: 8),
                  _AccuracyBadge(
                    loading: _accuracyLoading,
                    analysis: _accuracyAnalysis,
                    humanSide: _humanSide,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _shareResult,
                        icon: const Icon(Icons.share),
                        label: Text(l10n.shareButtonLabel),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ShogiReviewScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.insights),
                        label: Text(l10n.reviewTitle),
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
                            showAttackMap: ref.watch(showAttackMapProvider),
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

/// 終局後に表示する「あなたの正確度」バッジ。感想戦に明示的に入らないと
/// 見えない数字ではなく、対局直後の一番目立つ場所にまず数字そのものを
/// 出すことで、「AIが本当にコーチしてくれる」という価値を抽象的な宣伝
/// 文句ではなく具体的な体験として示す。タップすると感想戦画面に飛べる
/// （内訳を見るための自然な入口）。
class _AccuracyBadge extends StatelessWidget {
  const _AccuracyBadge({
    required this.loading,
    required this.analysis,
    required this.humanSide,
  });

  final bool loading;
  final GameAnalysis? analysis;
  final Side humanSide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(l10n.accuracyCalculatingMessage, style: const TextStyle(fontSize: 12)),
        ],
      );
    }
    final result = analysis;
    if (result == null) return const SizedBox.shrink();

    final accuracy = result.accuracyFor(humanSide);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ShogiReviewScreen()),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          l10n.yourAccuracyLabel(accuracy.toStringAsFixed(0)),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
