import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';

import '../../l10n/app_localizations.dart';

/// 既存の対局画面（`ShogiPvpGameScreen`）と同じタップ入力（駒をタップ→
/// 合法手ハイライト→移動先をタップ）を、Firestore 同期の対局状態から
/// 切り離して再利用できるようにした盤。描画は [ShogiBoardRenderer]、
/// 座標変換は [ShogiBoardRenderer.squareAt]、合法手は [ShogiGame.legalMoves]
/// をそのまま使う。既存の対局画面と同じく持ち駒の打ち込みは扱わない。
/// 成り/不成の両方が合法な場合はダイアログで選ばせる。
class ShogiMoveInputBoard extends StatefulWidget {
  const ShogiMoveInputBoard({
    super.key,
    required this.position,
    required this.onMove,
    this.enabled = true,
    this.lastMove,
    this.answerSquares = const [],
    this.maxSize = 400,
  });

  final ShogiPosition position;
  final ValueChanged<Move> onMove;
  final bool enabled;
  final Move? lastMove;

  /// 正解手などを強調表示するマス（合法手ドットと同じ表示を流用）。
  final List<Square> answerSquares;
  final double maxSize;

  @override
  State<ShogiMoveInputBoard> createState() => _ShogiMoveInputBoardState();
}

class _ShogiMoveInputBoardState extends State<ShogiMoveInputBoard> {
  final _renderer = ShogiBoardRenderer();
  final _game = ShogiGame();
  Square? _selected;
  List<Square> _hints = const [];

  @override
  void didUpdateWidget(covariant ShogiMoveInputBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.position, widget.position)) {
      _selected = null;
      _hints = const [];
    }
  }

  Future<void> _onTap(Square square) async {
    if (!widget.enabled) return;
    final legal =
        _game.legalMoves(widget.position).whereType<BoardMove>().toList();
    if (_selected == null || _selected == square) {
      final from = legal.where((m) => m.from == square).toList();
      setState(() {
        _selected = from.isEmpty || _selected == square ? null : square;
        _hints = _selected == null ? const [] : from.map((m) => m.to).toList();
      });
      return;
    }
    final matches =
        legal.where((m) => m.from == _selected && m.to == square).toList();
    if (matches.isEmpty) {
      // 別の自駒を選び直した場合
      final from = legal.where((m) => m.from == square).toList();
      setState(() {
        _selected = from.isEmpty ? null : square;
        _hints = from.map((m) => m.to).toList();
      });
      return;
    }
    setState(() {
      _selected = null;
      _hints = const [];
    });
    var move = matches.first;
    if (matches.length > 1) {
      final l10n = AppLocalizations.of(context)!;
      final promote = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.repertoirePromoteQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.repertoireNoPromote),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.repertoirePromote),
            ),
          ],
        ),
      );
      if (promote == null) return;
      move = matches.firstWhere((m) => m.promote == promote);
    }
    widget.onMove(move);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize =
            constraints.maxWidth.clamp(0, widget.maxSize).toDouble();
        return GestureDetector(
          key: const Key('shogi_move_input_board'),
          onTapUp: (details) {
            final square = _renderer.squareAt(
              BoardOffset(details.localPosition.dx, details.localPosition.dy),
              BoardSize(boardSize, boardSize),
              widget.position,
            );
            if (square != null) _onTap(square);
          },
          child: SizedBox(
            width: boardSize,
            child: _renderer.build(
              widget.position,
              lastMove: widget.lastMove,
              hints: [..._hints, ...widget.answerSquares],
              selected: _selected,
            ),
          ),
        );
      },
    );
  }
}
