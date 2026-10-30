import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../src/hybrid_battle/hybrid_battle_engine.dart';
import '../../src/piece.dart';

/// 期間限定イベント「将棋駒 vs チェス駒」の対局画面。
///
/// ルールはすべて [HybridBattleState]（`hybrid_battle_engine.dart`）に
/// 委ねる。2人で画面を回し合うローカル対局のみ（AI・オンライン・保存なし）。
/// 下側が将棋側（先手）、上側がチェス側。
class HybridBattleScreen extends StatefulWidget {
  const HybridBattleScreen({super.key});

  @override
  State<HybridBattleScreen> createState() => _HybridBattleScreenState();
}

class _HybridBattleScreenState extends State<HybridBattleScreen> {
  HybridBattleState _state = HybridBattleState.initial();

  (int, int)? _selected;
  ChessPieceType? _selectedDrop;
  List<HybridMove> _candidates = const [];

  void _clearSelection() {
    _selected = null;
    _selectedDrop = null;
    _candidates = const [];
  }

  void _newGame() => setState(() {
        _state = HybridBattleState.initial();
        _clearSelection();
      });

  Future<void> _onTapSquare(int r, int c) async {
    if (_state.result != HybridResult.ongoing) return;
    final matching =
        _candidates.where((m) => m.toRow == r && m.toCol == c).toList();
    if (matching.isNotEmpty) {
      final move = await _chooseMove(matching);
      if (move == null || !mounted) return;
      final next = _state.play(move);
      setState(() {
        if (next != null) _state = next;
        _clearSelection();
      });
      return;
    }
    final piece = _state.at(r, c);
    setState(() {
      if (piece != null && piece.side == _state.turn && _selected != (r, c)) {
        _selectedDrop = null;
        _selected = (r, c);
        _candidates = _state.legalMovesFrom(r, c);
      } else {
        _clearSelection();
      }
    });
  }

  void _onTapHand(ChessPieceType type) {
    if (_state.turn != HybridSide.chess ||
        _state.result != HybridResult.ongoing) {
      return;
    }
    setState(() {
      if (_selectedDrop == type) {
        _clearSelection();
        return;
      }
      _selected = null;
      _selectedDrop = type;
      _candidates = _state.legalMoves().where((m) => m.drop == type).toList();
    });
  }

  Future<HybridMove?> _chooseMove(List<HybridMove> moves) async {
    if (moves.length == 1) return moves.single;
    final l10n = AppLocalizations.of(context)!;
    if (moves.any((m) => m.chessPromotion != null)) {
      return showDialog<HybridMove>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.hybridChessPromotionTitle),
          children: [
            for (final m in moves)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, m),
                child: _ChessGlyph(type: m.chessPromotion!, size: 32),
              ),
          ],
        ),
      );
    }
    // 将棋駒の成る/成らない。
    final promote = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.hybridPromoteQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.hybridPromoteNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.hybridPromoteYes),
          ),
        ],
      ),
    );
    if (promote == null) return null;
    return moves.firstWhere((m) => m.promote == promote);
  }

  String _sideLabel(AppLocalizations l10n, HybridSide s) =>
      s == HybridSide.shogi
          ? l10n.hybridShogiSideLabel
          : l10n.hybridChessSideLabel;

  String _status(AppLocalizations l10n) {
    switch (_state.result) {
      case HybridResult.shogiWins:
        return l10n.hybridWinMessage(l10n.hybridShogiSideLabel);
      case HybridResult.chessWins:
        return l10n.hybridWinMessage(l10n.hybridChessSideLabel);
      case HybridResult.draw:
        return l10n.hybridDrawMessage;
      case HybridResult.ongoing:
        final check = _state.inCheck(_state.turn) ? l10n.chessCheckSuffix : '';
        return l10n.hybridTurnMessage(_sideLabel(l10n, _state.turn), check);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final hand = _state.chessHand.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hybridBattleTitle),
        actions: [
          IconButton(
            onPressed: _newGame,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.chessNewGameButton,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                l10n.hybridBattleRules,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                key: const Key('hybrid_status_text'),
                _status(l10n),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_state.result != HybridResult.ongoing) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _newGame,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.chessNewGameButton),
                ),
              ],
              const SizedBox(height: 8),
              Text(l10n.hybridChessHandLabel,
                  style: Theme.of(context).textTheme.labelMedium),
              Wrap(
                spacing: 4,
                children: [
                  for (final e in hand)
                    ChoiceChip(
                      key: Key('hybrid_hand_${e.key.name}'),
                      selected: _selectedDrop == e.key,
                      onSelected: (_) => _onTapHand(e.key),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChessGlyph(type: e.key, size: 20),
                          Text(' ×${e.value}'),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final boardSize = constraints.maxWidth.clamp(0, 450).toDouble();
                final sq = boardSize / 9;
                return SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: Column(
                    children: List.generate(9, (r) {
                      return Row(
                        children: List.generate(9, (c) {
                          final piece = _state.at(r, c);
                          final isSelected = _selected == (r, c);
                          final isTarget = _candidates
                              .any((m) => m.toRow == r && m.toCol == c);
                          return GestureDetector(
                            key: Key('hybrid_square_${r}_$c'),
                            onTap: () => _onTapSquare(r, c),
                            child: Container(
                              width: sq,
                              height: sq,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary.withValues(alpha: 0.5)
                                    : const Color(0xFFE8C48A),
                                border: Border.all(
                                    color: Colors.black54, width: 0.5),
                              ),
                              alignment: Alignment.center,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (isTarget)
                                    Container(
                                      width: sq * 0.3,
                                      height: sq * 0.3,
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary
                                            .withValues(alpha: 0.7),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (piece != null)
                                    piece.side == HybridSide.shogi
                                        ? Text(
                                            pieceLabel(piece.shogiType!) == '王'
                                                ? '玉'
                                                : pieceLabel(piece.shogiType!),
                                            style: TextStyle(
                                              fontSize: sq * 0.55,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  Piece(piece.shogiType!, true)
                                                          .isPromoted
                                                      ? Colors.red.shade800
                                                      : Colors.black,
                                            ),
                                          )
                                        : _ChessGlyph(
                                            type: piece.chessType!,
                                            size: sq * 0.65),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// チェス駒の描画。白抜きの記号（♔など）は文字色に関係なく輪郭線しか
/// 塗られず判別しにくいため、塗りつぶし記号（♚など）を常に使い、
/// 下に一回り大きい白い同じ記号を重ねて縁取りにする（Stackパターン）。
class _ChessGlyph extends StatelessWidget {
  const _ChessGlyph({required this.type, required this.size});

  final ChessPieceType type;
  final double size;

  static const _solid = {
    ChessPieceType.pawn: '♟',
    ChessPieceType.knight: '♞',
    ChessPieceType.bishop: '♝',
    ChessPieceType.rook: '♜',
    ChessPieceType.queen: '♛',
    ChessPieceType.king: '♚',
  };

  @override
  Widget build(BuildContext context) {
    final glyph = _solid[type]!;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          glyph,
          style: TextStyle(
            fontSize: size,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.08
              ..color = Colors.white,
          ),
        ),
        Text(glyph,
            style: TextStyle(fontSize: size, color: Colors.indigo.shade900)),
      ],
    );
  }
}
