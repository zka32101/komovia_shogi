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
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown)),
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
    return HomeScreen(
      onPlayShogi: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ShogiGameScreen()),
        );
      },
    );
  }
}

/// AI strength from weak (for beginners) to reasonably strong - deliberately
/// not the engine's absolute strongest, since `AI.bestMove`'s plain
/// alpha-beta without any time budget gets slow well before that on a
/// mobile CPU. [depth] is passed straight through to `ShogiEngine.
/// bestMove`'s `level` parameter, which `ai_isolate_worker.dart` forwards
/// unchanged to `logic.dart`'s `AI.bestMove(..., depth)` - depth 0 there
/// means "shuffle legal moves and pick one", not a shallow search, so it's
/// the only level genuinely weak enough for an absolute beginner.
enum ShogiDifficulty {
  beginner,
  easy,
  medium,
  hard,
}

extension ShogiDifficultyExt on ShogiDifficulty {
  int get depth => switch (this) {
        ShogiDifficulty.beginner => 0,
        ShogiDifficulty.easy => 1,
        ShogiDifficulty.medium => 3,
        ShogiDifficulty.hard => 5,
      };

  String get displayName => switch (this) {
        ShogiDifficulty.beginner => '初心者向け',
        ShogiDifficulty.easy => 'やさしい',
        ShogiDifficulty.medium => 'ふつう',
        ShogiDifficulty.hard => '強い',
      };

  String get description => switch (this) {
        ShogiDifficulty.beginner => 'ランダムに近い手。将棋を始めたばかりの方向け。',
        ShogiDifficulty.easy => '簡単な読みのみ。油断すると負けることもあります。',
        ShogiDifficulty.medium => '基本的な戦術を踏まえて指します。',
        ShogiDifficulty.hard => 'しっかり読んで指します。手応えのある相手です。',
      };
}

class ShogiGameScreen extends StatefulWidget {
  const ShogiGameScreen({super.key});

  @override
  State<ShogiGameScreen> createState() => _ShogiGameScreenState();
}

class _ShogiGameScreenState extends State<ShogiGameScreen> {
  final _game = ShogiGame();
  final _engine = ShogiEngine();
  final _renderer = ShogiBoardRenderer();

  late ShogiPosition _position;
  Move? _lastMove;
  Square? _selected;
  List<Square> _hints = const [];
  bool _aiThinking = false;
  String _status = '';
  int _moveCount = 0;
  GameResult _result = GameResult.ongoing;
  ShogiDifficulty _difficulty = ShogiDifficulty.medium;

  // 「待った」用の局面履歴。手を打つたびに「打つ前」の局面を積んでおき、
  // undoではその局面に直接戻す（chess/goのように手リストから再生するの
  // ではなく、局面そのものを保存している — ShogiPositionは不変なので
  // 安全に共有できる）。
  final List<ShogiPosition> _positionHistory = [];

  bool get _canUndo => _positionHistory.isNotEmpty && !_aiThinking;

  bool _hintLoading = false;

  bool get _canRequestHint =>
      !_aiThinking &&
      !_hintLoading &&
      _result.isOngoing &&
      _position.sideToMove == _humanSide;

  @override
  void initState() {
    super.initState();
    _position = _game.initialPosition();
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
    final selected = await showDialog<ShogiDifficulty>(
      context: context,
      barrierDismissible: !restartGame,
      builder: (context) => SimpleDialog(
        title: const Text('AIの強さを選んでください'),
        children: ShogiDifficulty.values
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(d),
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
            )
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _difficulty = selected);
    if (restartGame) _newGame();
  }

  Side get _humanSide => Side.first;

  void _onTapSquare(Square square) {
    if (_aiThinking || _position.sideToMove != _humanSide) return;

    final legal = _game.legalMoves(_position);
    if (_selected == null) {
      final movesFromHere = legal
          .whereType<BoardMove>()
          .where((m) => m.from == square)
          .toList();
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
    setState(() {
      _positionHistory.add(_position);
      _position = _game.apply(_position, move);
      _lastMove = move;
      _moveCount++;
    });
    _checkResultOrLetAiMove();
  }

  /// 直前の自分の手（とそれに対するAIの応手があれば、それも）を取り消す。
  /// 人間の手番に戻るまで局面履歴を遡る — 通常は2手（自分の手+AIの応手）
  /// だが、その手で終局していた場合は1手だけ遡れば人間の手番に戻る。
  void _undo() {
    if (!_canUndo) return;
    setState(() {
      while (_positionHistory.isNotEmpty) {
        _position = _positionHistory.removeLast();
        _moveCount--;
        if (_position.sideToMove == _humanSide) break;
      }
      _lastMove = null;
      _selected = null;
      _hints = const [];
      _status = '';
      _result = _game.result(_position);
    });
  }

  /// 次の一手のヒントを示す。現在選択中の差し手の強さ(_difficulty)とは
  /// 独立に、常に`ShogiDifficulty.hard`相当の深さで読んで提案する —
  /// 弱いAIを選んでいても、ヒント自体は手加減しない本気の一手にする。
  /// 提案手は通常の「駒を選択して行き先をハイライト」と同じ見た目
  /// （_selected/_hints）で示すため、そのままタップして着手できる。
  Future<void> _showHint() async {
    if (!_canRequestHint) return;
    setState(() => _hintLoading = true);
    final move = await _engine.bestMove(_position, level: ShogiDifficulty.hard.depth);
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
    final result = _game.result(_position);
    if (!result.isOngoing) {
      setState(() {
        _status = _describeResult(result);
        _result = result;
      });
      return;
    }
    if (_position.sideToMove == _humanSide) return;

    setState(() {
      _aiThinking = true;
      _status = 'AI考慮中…';
    });
    final move = await _engine.bestMove(_position, level: _difficulty.depth);
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
        return '$winner勝ち';
      case ResultKind.draw:
        return '引き分け';
      case ResultKind.ongoing:
        return '';
    }
  }

  void _newGame() {
    setState(() {
      _position = _game.initialPosition();
      _lastMove = null;
      _selected = null;
      _hints = const [];
      _status = '';
      _moveCount = 0;
      _result = GameResult.ongoing;
      _positionHistory.clear();
    });
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
          statLines: ['手数: $_moveCount手'],
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
            tooltip: 'AIの強さ（現在: ${_difficulty.displayName}）',
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
          IconButton(onPressed: _newGame, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status.isEmpty ? '先手（あなた）の番です' : _status,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!_result.isOngoing) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _shareResult,
                  icon: const Icon(Icons.share),
                  label: const Text('SNSでシェア'),
                ),
              ],
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.maxWidth.clamp(0, 400).toDouble();
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
                        width: boardSize,
                        height: boardSize,
                        child: _renderer.build(
                          _position,
                          lastMove: _lastMove,
                          hints: _hints,
                          selected: _selected,
                          textured: true,
                          advantageRatio:
                              ShogiBoardRenderer.materialAdvantageRatio(_position),
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
    );
  }
}
