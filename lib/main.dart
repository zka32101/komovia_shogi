import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

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

  @override
  void initState() {
    super.initState();
    _position = _game.initialPosition();
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
      _position = _game.apply(_position, move);
      _lastMove = move;
    });
    _checkResultOrLetAiMove();
  }

  Future<void> _checkResultOrLetAiMove() async {
    final result = _game.result(_position);
    if (!result.isOngoing) {
      setState(() => _status = _describeResult(result));
      return;
    }
    if (_position.sideToMove == _humanSide) return;

    setState(() {
      _aiThinking = true;
      _status = 'AI考慮中…';
    });
    final move = await _engine.bestMove(_position, level: 2);
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Komovia Shogi'),
        actions: [
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
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.maxWidth.clamp(0, 400).toDouble();
                    return GestureDetector(
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
