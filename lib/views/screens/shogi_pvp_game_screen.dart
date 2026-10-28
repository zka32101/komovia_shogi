import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import '../../models/shogi_pvp_game.dart';
import '../../viewmodels/index.dart';

/// PvP対局画面。`ShogiGameScreen`（main.dart、AI対局）と同じタップ操作
/// （駒をタップ→合法手ハイライト→タップで着手）だが、盤面は
/// [ShogiPvpGame.kifMoves]をFirestoreから購読し、他プレイヤーの着手も
/// リアルタイムに反映される。`ShogiGameScreen`と同じく、持ち駒からの
/// 打ち込み（DropMove）はこの画面でもまだ扱わない（既存の制約を
/// そのまま踏襲 — このPRで新たに加えた簡略化ではない）。
class ShogiPvpGameScreen extends ConsumerStatefulWidget {
  const ShogiPvpGameScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<ShogiPvpGameScreen> createState() =>
      _ShogiPvpGameScreenState();
}

class _ShogiPvpGameScreenState extends ConsumerState<ShogiPvpGameScreen> {
  final _renderer = ShogiBoardRenderer();
  final _game = ShogiGame();

  Square? _selected;
  List<Square> _hints = const [];
  String? _errorMessage;

  /// [ShogiPvpGame.kifMoves]を初期局面から打ち直して再構成する。
  /// `ShogiPvpGameService._replay`/`resumeShogiGameProvider`と同じロジック
  /// （盤面をFirestoreへ直接保存しない設計である以上、読む側は必ずこの
  /// 再構成を行う必要がある — 3箇所で重複しているのは、サービス層の
  /// プライベートメソッドを画面側に公開するより、ロジック自体が短く
  /// 安定しているためそれぞれ素直に書いた方が良いと判断したもの）。
  (ShogiPosition, List<Object>) _replay(String kifMoves) {
    var position = _game.initialPosition();
    final historyKeys = <Object>[_game.positionKey(position)];
    if (kifMoves.isNotEmpty) {
      final record = _game.importRecord(kifMoves);
      for (final recorded in record.moves) {
        position = _game.apply(position, recorded.move);
        historyKeys.add(_game.positionKey(position));
      }
    }
    return (position, historyKeys);
  }

  Side? _humanSide(ShogiPvpGame pvp, String uid) {
    final color = pvp.playerColorOf(uid);
    if (color == 1) return Side.first;
    if (color == 2) return Side.second;
    return null;
  }

  void _onTapSquare(
    Square square,
    ShogiPvpGame pvp,
    ShogiPosition position,
    List<Object> historyKeys,
    String uid,
  ) {
    if (!pvp.isTurnOf(uid)) return;

    final legal = _game.legalMoves(position, historyKeys: historyKeys);
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

    final matches = legal
        .whereType<BoardMove>()
        .where((m) => m.from == _selected && m.to == square)
        .toList();
    setState(() {
      _selected = null;
      _hints = const [];
    });
    if (matches.isNotEmpty) {
      _applyMove(matches.first, uid);
    }
  }

  Future<void> _applyMove(Move move, String uid) async {
    final applied =
        await ref.read(applyShogiPvpMoveProvider)(widget.gameId, uid, move);
    if (!mounted) return;
    if (!applied) {
      setState(() => _errorMessage = 'その手は指せません');
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _confirmResign(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投了しますか？'),
        content: const Text('投了すると対局が終了します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('投了する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(resignShogiPvpGameProvider)(widget.gameId, uid);
  }

  String _statusText(ShogiPvpGame pvp, Side? humanSide) {
    if (pvp.isFinished) {
      if (pvp.winnerUid == null) return '対局が終了しました';
      final uid = ref.read(currentUidProvider);
      if (uid == pvp.winnerUid) return 'あなたの勝ちです！';
      return 'あなたの負けです';
    }
    if (humanSide == null) return '観戦中';
    return pvp.isTurnOf(ref.read(currentUidProvider) ?? '')
        ? 'あなたの番です'
        : '相手の番です';
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final gameAsync = ref.watch(shogiPvpGameStreamProvider(widget.gameId));

    return Scaffold(
      appBar: AppBar(title: const Text('対局')),
      body: gameAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('読み込みに失敗しました: $error')),
        data: (pvp) {
          if (uid == null) {
            return const Center(child: Text('ログインが必要です'));
          }
          final (position, historyKeys) = _replay(pvp.kifMoves);
          final humanSide = _humanSide(pvp, uid);

          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusText(pvp, humanSide),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize =
                            constraints.maxWidth.clamp(0, 400).toDouble();
                        return GestureDetector(
                          key: const Key('shogi_pvp_board_gesture_detector'),
                          onTapUp: (details) {
                            final square = _renderer.squareAt(
                              BoardOffset(
                                details.localPosition.dx,
                                details.localPosition.dy,
                              ),
                              BoardSize(boardSize, boardSize),
                              position,
                            );
                            if (square != null) {
                              _onTapSquare(
                                square,
                                pvp,
                                position,
                                historyKeys,
                                uid,
                              );
                            }
                          },
                          child: SizedBox(
                            width: boardSize,
                            child: _renderer.build(
                              position,
                              hints: _hints,
                              selected: _selected,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (pvp.isActive && humanSide != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OutlinedButton(
                        onPressed: () => _confirmResign(uid),
                        child: const Text('投了する'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
