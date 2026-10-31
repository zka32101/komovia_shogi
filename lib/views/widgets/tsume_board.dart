import 'package:flutter/material.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/komovia_shogi.dart';
import 'package:komovia_shogi/src/piece.dart';

import '../../l10n/app_localizations.dart';

/// 詰将棋用の入力盤。`ShogiMoveInputBoard`（定跡訓練）と同じタップ入力
/// （駒をタップ→合法手ドット→移動先をタップ、成/不成ダイアログ）に加え、
/// 詰将棋で必須の「持ち駒の打ち込み」を扱う: 盤の下の持ち駒チップを選ぶと
/// 打てるマスがドット表示され、そこをタップすると打つ。
/// `ShogiMoveInputBoard` は定跡訓練専用の別機能なので変更せず、
/// 同じパターンをこちらに複製している。
class TsumeBoard extends StatefulWidget {
  const TsumeBoard({
    super.key,
    required this.position,
    required this.onMove,
    this.enabled = true,
    this.lastMove,
    this.maxSize = 400,
  });

  final ShogiPosition position;
  final ValueChanged<Move> onMove;
  final bool enabled;
  final Move? lastMove;
  final double maxSize;

  @override
  State<TsumeBoard> createState() => _TsumeBoardState();
}

class _TsumeBoardState extends State<TsumeBoard> {
  final _renderer = ShogiBoardRenderer();
  final _game = ShogiGame();
  Square? _selected;
  PieceType? _dropType;
  List<Square> _hints = const [];

  @override
  void didUpdateWidget(covariant TsumeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.position, widget.position)) _clear();
  }

  void _clear() {
    _selected = null;
    _dropType = null;
    _hints = const [];
  }

  List<Move> get _legal => _game.legalMoves(widget.position);

  void _selectDrop(PieceType type) {
    if (!widget.enabled) return;
    setState(() {
      if (_dropType == type) {
        _clear();
        return;
      }
      _selected = null;
      _dropType = type;
      _hints = [
        for (final m in _legal.whereType<DropMove>())
          if (m.pieceType == type.name) m.to,
      ];
    });
  }

  Future<void> _onTap(Square square) async {
    if (!widget.enabled) return;
    if (_dropType != null) {
      final drop = DropMove(pieceType: _dropType!.name, to: square);
      if (_legal.contains(drop)) {
        setState(_clear);
        widget.onMove(drop);
        return;
      }
      setState(_clear);
    }
    final legal = _legal.whereType<BoardMove>().toList();
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
      final from = legal.where((m) => m.from == square).toList();
      setState(() {
        _selected = from.isEmpty ? null : square;
        _hints = from.map((m) => m.to).toList();
      });
      return;
    }
    setState(_clear);
    var move = matches.first;
    if (matches.length > 1) {
      final l10n = AppLocalizations.of(context)!;
      final promote = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.tsumePromoteQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.tsumeNoPromote),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.tsumePromote),
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
    final l10n = AppLocalizations.of(context)!;
    final hand = widget.position.sideToMove == Side.first
        ? widget.position.p1Hand
        : widget.position.p2Hand;
    final handTypes = [
      for (final t in PieceType.values)
        if ((hand[t] ?? 0) > 0) t,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final boardSize =
                constraints.maxWidth.clamp(0, widget.maxSize).toDouble();
            return GestureDetector(
              key: const Key('tsume_board'),
              onTapUp: (details) {
                final square = _renderer.squareAt(
                  BoardOffset(
                      details.localPosition.dx, details.localPosition.dy),
                  BoardSize(boardSize, boardSize),
                  widget.position,
                );
                if (square != null) _onTap(square);
              },
              child: SizedBox(
                width: boardSize,
                // 持ち駒は下のチップで表示する。盤描画側に持ち駒を渡すと
                // 盤の上に持ち駒行が入り squareAt の座標がずれるため空にする。
                child: _renderer.build(
                  widget.position.copyWith(p1Hand: const {}, p2Hand: const {}),
                  lastMove: widget.lastMove,
                  hints: _hints,
                  selected: _selected,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.tsumeHandLabel),
            if (handTypes.isEmpty) Text(l10n.tsumeHandNone),
            for (final t in handTypes)
              ChoiceChip(
                key: Key('tsume_hand_${t.name}'),
                label: Text('${pieceLabel(t)}×${hand[t]}'),
                selected: _dropType == t,
                onSelected: widget.enabled ? (_) => _selectDrop(t) : null,
              ),
          ],
        ),
      ],
    );
  }
}
