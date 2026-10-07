import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The board's wood-grain texture background, ported from
/// `kouki-shogi`'s `BoardPainter` (`_drawWoodGrain`, the gradient base,
/// and the top gloss highlight). Meant to be painted *behind* a cell
/// grid whose cells are transparent where no highlight is active, so
/// the grain actually shows through — see `MiniBoardWidget`'s `textured`
/// flag, which switches its per-cell background accordingly. (The
/// original `BoardPainter` was instead painted under an always-opaque
/// cell grid in `game_screen.dart`, which made this texture invisible
/// in practice.)
class BoardBackgroundPainter extends CustomPainter {
  final Color gradientTop;
  final Color gradientBottom;

  const BoardBackgroundPainter({
    required this.gradientTop,
    required this.gradientBottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientTop, gradientBottom],
        ).createShader(rect),
    );
    _drawWoodGrain(canvas, size);
    final topHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withAlpha(38), Colors.white.withAlpha(0)],
        stops: const [0.0, 0.25],
      ).createShader(rect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.25),
      topHighlight,
    );
  }

  void _drawWoodGrain(Canvas canvas, Size size) {
    // Seeded so the pattern doesn't shift between repaints.
    final rng = math.Random(42);
    final grainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const lineCount = 18;
    final baseSpacing = size.height / lineCount;
    var yPos = baseSpacing * 0.3;

    for (var i = 0; i < lineCount; i++) {
      final alpha = 8 + rng.nextInt(14);
      grainPaint.color = Color.fromARGB(alpha, 0x3E, 0x27, 0x23);
      grainPaint.strokeWidth = 0.4 + rng.nextDouble() * 0.8;

      final path = Path();
      const segments = 9;
      path.moveTo(0, yPos);
      for (var s = 1; s <= segments; s++) {
        final xPrev = size.width * (s - 1) / segments;
        final xCurr = size.width * s / segments;
        final waveY = yPos + math.sin(s * 1.3 + i * 0.7) * 1.8;
        path.quadraticBezierTo(
          xPrev + (xCurr - xPrev) * 0.5,
          yPos + math.sin((s - 0.5) * 1.3 + i * 0.7) * 1.5,
          xCurr,
          waveY,
        );
      }
      canvas.drawPath(path, grainPaint);
      yPos += baseSpacing * (0.7 + rng.nextDouble() * 0.6);
    }
  }

  @override
  bool shouldRepaint(covariant BoardBackgroundPainter old) =>
      old.gradientTop != gradientTop || old.gradientBottom != gradientBottom;
}

/// A material-advantage tint over the whole board. [ratio] is 先手's
/// share of total piece value (0.5 = even), matching
/// `ShogiBoardRenderer.materialAdvantageRatio`'s convention.
///
/// Ported from `BoardPainter.advantageRatio`'s blend logic, but painted
/// *above* the cell grid rather than below it: `game_screen.dart`
/// painted it under an always-opaque per-cell background, which made it
/// invisible in practice. An overlay is only useful if it's visible, so
/// this is a deliberate fix, not a bug-for-bug port.
class AdvantageOverlayPainter extends CustomPainter {
  final double ratio;

  const AdvantageOverlayPainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    if (ratio == 0.5) return;
    final Color color;
    if (ratio > 0.5) {
      final blend = ((ratio - 0.5) * 2).clamp(0.0, 1.0);
      color = Color.lerp(
        Colors.transparent,
        Colors.blue.shade900.withAlpha(40),
        blend,
      )!;
    } else {
      final blend = ((0.5 - ratio) * 2).clamp(0.0, 1.0);
      color = Color.lerp(
        Colors.transparent,
        Colors.red.shade900.withAlpha(40),
        blend,
      )!;
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant AdvantageOverlayPainter old) =>
      old.ratio != ratio;
}
