// lib/mini_board_widget.dart
import 'package:flutter/material.dart';
import 'piece.dart';
import 'theme/app_theme.dart';
import 'widgets/board_background_painter.dart';
import 'widgets/koma_painter.dart';

class MiniBoardWidget extends StatelessWidget {
  final List<List<Piece?>> board;
  final Set<(int, int)> moveDots;        // Green dots for legal moves
  final (int, int)? lastMoveFrom;        // Amber tint (last move source)
  final (int, int)? lastMoveTo;          // Amber border (last move dest)
  final (int, int)? hintFrom;            // Cyan (best move source)
  final (int, int)? hintTo;              // Cyan (best move dest)
  final Set<(int, int)> highlightSquares;// Light blue highlight squares
  final bool showLabels;                  // Show rank/file labels
  final double? size;                     // Board size override
  final bool? currentIsP1;               // null=none, true=p1 is current turn, false=p2 is current turn
  final bool boardFlipped;               // ボード反転時の駒向き調整
  final Map<PieceType, int> p1Hand;      // 先手持ち駒（表示用）
  final Map<PieceType, int> p2Hand;      // 後手持ち駒（表示用）
  final List<List<int>>? p1AttackMap;    // 効き可視化: 先手の利き数（null=非表示）
  final List<List<int>>? p2AttackMap;    // 効き可視化: 後手の利き数（null=非表示）
  final bool textured;                   // 木目調の盤背景（§3-5「洗練されたUI」）
  final double? advantageRatio;          // 有利度オーバーレイ（null=非表示、0.5=互角）

  const MiniBoardWidget({
    super.key,
    required this.board,
    this.moveDots = const {},
    this.lastMoveFrom,
    this.lastMoveTo,
    this.hintFrom,
    this.hintTo,
    this.highlightSquares = const {},
    this.showLabels = true,
    this.size,
    this.currentIsP1,
    this.boardFlipped = false,
    this.p1Hand = const {},
    this.p2Hand = const {},
    this.p1AttackMap,
    this.p2AttackMap,
    this.textured = false,
    this.advantageRatio,
  });

  // Colors matching game_screen.dart standard theme
  static const _cellColor = Color(0xFFDEB887);
  static const _cellBorder = Color(0xFF7A4E2B);

  // Colors matching game_screen.dart's PieceTheme.textured
  static const _texturedBorder = Color(0xFF8D6E63);
  static const _texturedGradientTop = Color(0xFF3E2723);
  static const _texturedGradientBottom = Color(0xFF5D4037);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final totalSize = size ?? constraints.maxWidth;
      final labelSize = showLabels ? totalSize * 0.05 : 0.0;
      final boardSize = totalSize - labelSize;
      // 外枠(2px×2)の内側に9マスを収める（枠込みの幅で割ると右/下が4px溢れる）
      final cellSize = (boardSize - 4) / 9;

      Widget cellGrid = Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(9, (r) =>
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(9, (c) {
                final piece = board[r][c];
                final isDot = moveDots.contains((r, c));
                final isHL = highlightSquares.contains((r, c));
                final isLastTo = lastMoveTo == (r, c);
                final isLastFr = lastMoveFrom == (r, c);
                final isHintFr = hintFrom == (r, c);
                final isHintTo = hintTo == (r, c);

                Color bg = _cellColor;
                // 効き（利き）可視化: 先手=青、後手=赤、両方=紫
                if (p1AttackMap != null && p2AttackMap != null) {
                  final p1V = p1AttackMap![r][c];
                  final p2V = p2AttackMap![r][c];
                  final baseIntensity = piece != null ? 0.18 : 0.36;
                  if (p1V > 0 && p2V == 0) {
                    bg = Color.lerp(bg, Colors.blue.shade300, baseIntensity)!;
                  } else if (p2V > 0 && p1V == 0) {
                    bg = Color.lerp(bg, Colors.red.shade300, baseIntensity)!;
                  } else if (p1V > 0 && p2V > 0) {
                    bg = Color.lerp(bg, Colors.purple.shade300, baseIntensity * 0.7)!;
                  }
                }
                // 現在手番の駒に薄いハイライト
                if (currentIsP1 != null && piece != null) {
                  if (piece.isPlayer1 == currentIsP1) {
                    bg = Color.lerp(bg, Colors.blue.shade200, 0.18)!;
                  } else {
                    bg = Color.lerp(bg, Colors.red.shade200, 0.12)!;
                  }
                }
                if (isLastFr) bg = Color.lerp(_cellColor, Colors.amber.shade200, 0.35)!;
                if (isLastTo) bg = Color.lerp(_cellColor, Colors.amber.shade300, 0.55)!;
                if (isHintFr) bg = AppTheme.accent;
                if (isHintTo) bg = AppTheme.accent;
                if (isHL) bg = Colors.lightBlue.shade100;

                // When textured, an unhighlighted cell stays transparent
                // so the wood-grain background painted behind the grid
                // shows through; a highlighted cell keeps its tint, just
                // blended at lower opacity over that background.
                final isDefaultBg = bg == _cellColor;
                final cellBg = textured
                    ? (isDefaultBg
                        ? Colors.transparent
                        : Color.lerp(Colors.transparent, bg, 0.55))
                    : bg;

                return Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: cellBg,
                    border: isLastTo && hintTo == null
                        ? Border.all(color: Colors.amber.shade600, width: 1.5)
                        : isHintTo
                        ? Border.all(color: AppTheme.accent, width: 1.5)
                        : Border.all(
                            color: textured ? _texturedBorder : _cellBorder,
                            width: 0.6,
                          ),
                  ),
                  child: Stack(children: [
                    if (piece != null)
                      Center(
                        child: SizedBox(
                          // 対局盤と同じ五角形の駒（KomaPainter）で見た目を統一
                          width: cellSize * 0.88,
                          height: cellSize * 0.88,
                          child: CustomPaint(
                            painter: KomaPainter(
                              pointsUp: boardFlipped ? !piece.isPlayer1 : piece.isPlayer1,
                              fill: const Color(0xFFF4DDA6),
                              border: const Color(0xFFC49A4E),
                            ),
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: (boardFlipped ? !piece.isPlayer1 : piece.isPlayer1) ? 0 : 2,
                                child: Text(
                                  piece.label,
                                  style: komaLabelStyle(
                                    isPromoted: piece.isPromoted,
                                    fontSize: cellSize * 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (isDot)
                      Center(
                        child: Container(
                          width: cellSize * 0.35,
                          height: cellSize * 0.35,
                          decoration: BoxDecoration(
                            color: Colors.green.shade500.withAlpha(170),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ]),
                );
              }),
            ),
          ),
      );

      final boardGrid = Container(
        width: boardSize,
        height: boardSize,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          border: Border.all(
            color: textured ? _texturedBorder : const Color(0xFF4A2E0A),
            width: 2,
          ),
          color: textured ? null : _cellColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(1, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (textured)
              Positioned.fill(
                child: CustomPaint(
                  painter: const BoardBackgroundPainter(
                    gradientTop: _texturedGradientTop,
                    gradientBottom: _texturedGradientBottom,
                  ),
                ),
              ),
            cellGrid,
            if (advantageRatio != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: AdvantageOverlayPainter(ratio: advantageRatio!),
                  ),
                ),
              ),
          ],
        ),
      );

      // 持ち駒バー
      Widget handRow(Map<PieceType, int> hand, String label, Color labelColor) {
        if (hand.isEmpty) return const SizedBox.shrink();
        final pieces = hand.entries.map((e) {
          final pLabel = pieceLabel(e.key);
          return Text(
            e.value > 1 ? '$pLabel×${e.value}' : pLabel,
            style: TextStyle(
              fontSize: cellSize * 0.52,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C1A0A),
            ),
          );
        }).toList();
        return Container(
          width: boardSize,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          color: const Color(0xFFC8A46A),
          child: Row(
            children: [
              Text('$label持駒: ',
                  style: TextStyle(
                      color: labelColor, fontSize: cellSize * 0.45, fontWeight: FontWeight.bold)),
              Wrap(spacing: 6, children: pieces),
            ],
          ),
        );
      }

      if (!showLabels) {
        if (p1Hand.isEmpty && p2Hand.isEmpty) return boardGrid;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            handRow(p2Hand, '後手', Colors.red.shade700),
            boardGrid,
            handRow(p1Hand, '先手', Colors.blue.shade700),
          ],
        );
      }

      const rankKanji = ['一','二','三','四','五','六','七','八','九'];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 後手持ち駒（盤の上）
          if (p2Hand.isNotEmpty) handRow(p2Hand, '後手', Colors.red.shade700),
          Row(children: [
            SizedBox(width: labelSize),
            ...List.generate(9, (i) => SizedBox(
              width: cellSize,
              child: Text('${9 - i}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: labelSize * 0.7)),
            )),
          ]),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: List.generate(9, (i) => SizedBox(
                width: labelSize,
                height: cellSize,
                child: Center(child: Text(rankKanji[i],
                  style: TextStyle(color: Colors.white54, fontSize: labelSize * 0.7))),
              ))),
              boardGrid,
            ],
          ),
          // 先手持ち駒（盤の下）
          if (p1Hand.isNotEmpty) handRow(p1Hand, '先手', Colors.blue.shade700),
        ],
      );
    });
  }
}
