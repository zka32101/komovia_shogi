// lib/widgets/koma_painter.dart
// 将棋駒の五角形描画（光沢グラデーション付き）

import 'package:flutter/material.dart';

/// 駒の文字ラベル共通スタイル（視認性向上：淡いハイライト＋影で立体的に）
TextStyle komaLabelStyle({
  required bool isPromoted,
  required double fontSize,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    color: isPromoted ? const Color(0xFFB3261E) : const Color(0xFF2C1A0A),
    height: 1.0,
    shadows: [
      Shadow(
        color: isPromoted
            ? const Color(0xFFB3261E).withAlpha(60)
            : Colors.black.withAlpha(50),
        offset: const Offset(0.6, 0.9),
        blurRadius: 1.2,
      ),
      Shadow(
        color: Colors.white.withAlpha(90),
        offset: const Offset(-0.4, -0.4),
        blurRadius: 0.6,
      ),
    ],
  );
}

class KomaPainter extends CustomPainter {
  final bool pointsUp;
  final Color fill;
  final Color border;
  const KomaPainter({
    required this.pointsUp,
    required this.fill,
    required this.border,
  });

  Path _koma(double w, double h, double dx, double dy) {
    final cx = w / 2 + dx;
    final apexY = (pointsUp ? 0.05 : 0.95) * h + dy;
    final shoulderY = (pointsUp ? 0.26 : 0.74) * h + dy;
    final baseY = (pointsUp ? 0.96 : 0.04) * h + dy;
    final halfTop = w * 0.34;
    final halfBottom = w * 0.44;
    return Path()
      ..moveTo(cx, apexY)
      ..lineTo(cx + halfTop, shoulderY)
      ..lineTo(cx + halfBottom, baseY)
      ..lineTo(cx - halfBottom, baseY)
      ..lineTo(cx - halfTop, shoulderY)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final komaPath = _koma(w, h, 0, 0);

    // ── 1. 影（ソフトシャドウ：2レイヤー） ───────────────────────────────
    canvas.drawPath(
      _koma(w, h, 1.5, 2.5),
      Paint()..color = Colors.black.withAlpha(28),
    );
    canvas.drawPath(
      _koma(w, h, 0.7, 1.2),
      Paint()..color = Colors.black.withAlpha(42),
    );

    // ── 2. 駒本体（木目を思わせる縦グラデーション：上は明るく下はやや濃く）──
    final woodBase = Color.lerp(fill, Colors.white, 0.16)!;
    final woodEdge = Color.lerp(fill, const Color(0xFF6B4A1E), 0.22)!;
    canvas.drawPath(
      komaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [woodBase, fill, woodEdge],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ── 3. 木目筋（ごく淡い横縞を数本、質感を出す） ──────────────────────
    canvas.save();
    canvas.clipPath(komaPath);
    final grainPaint = Paint()
      ..color = const Color(0xFF6B4A1E).withAlpha(18)
      ..strokeWidth = 0.7;
    for (int i = 1; i <= 4; i++) {
      final y = h * (i / 5) + (i.isEven ? 1.5 : -1.0);
      canvas.drawLine(Offset(w * 0.08, y), Offset(w * 0.92, y), grainPaint);
    }
    canvas.restore();

    // ── 4. 光沢グラデーション（上部1/3に白ハイライト） ───────────────────
    final glowTop = pointsUp ? 0.0 : 0.6;
    final glowBot = pointsUp ? 0.45 : 1.0;
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0, pointsUp ? -1.0 : 1.0),
        end: Alignment(0, pointsUp ? 0.2 : -0.2),
        colors: [
          Colors.white.withAlpha(110),
          Colors.white.withAlpha(0),
        ],
      ).createShader(
        Rect.fromLTWH(0, h * glowTop, w, h * (glowBot - glowTop)),
      );
    canvas.drawPath(komaPath, glossPaint);

    // ── 5. 底部の接地陰（立体感を強める） ─────────────────────────────────
    final groundShadowY = pointsUp ? 0.86 : 0.14;
    final groundShadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment(0, pointsUp ? 1.0 : -1.0),
        end: Alignment(0, pointsUp ? 0.55 : -0.55),
        colors: [Colors.black.withAlpha(50), Colors.black.withAlpha(0)],
      ).createShader(Rect.fromLTWH(0, h * groundShadowY, w, h * 0.14));
    canvas.drawPath(komaPath, groundShadow);

    // ── 6. 縁取り（やや濃くして輪郭をはっきりさせる） ─────────────────────
    canvas.drawPath(
      komaPath,
      Paint()
        ..color = Color.lerp(border, Colors.black, 0.18)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── 7. 内側の細い縁（立体感） ─────────────────────────────────────────
    canvas.drawPath(
      _koma(w * 0.88, h * 0.88, w * 0.06, h * (pointsUp ? 0.05 : 0.06)),
      Paint()
        ..color = Colors.white.withAlpha(65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant KomaPainter old) =>
      old.pointsUp != pointsUp || old.fill != fill || old.border != border;
}
