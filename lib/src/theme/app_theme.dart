// lib/theme/app_theme.dart
// アプリ全体のデザイントークン（色・余白・角丸・影）を一元管理する。
// 主色=金（アクセント）、背景=墨色。盤面・駒・囲い完成バナーで既に使われている
// 「墨・金・朱・藍・松葉」という将棋の意匠語彙に統一する（落ち着いた和のトーン）。
// 各画面はここを参照して見た目を統一すること。

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── カラー ────────────────────────────────────────────────
  static const bg          = Color(0xFF15110C); // 墨（画面背景）
  static const surface     = Color(0xFF201A13); // 生成（カード/バー）
  static const surfaceHigh = Color(0xFF2A2115); // 強調面
  static const primary     = Color(0xFF4E6A8C); // 藍（先手・情報・二次操作）
  static const primaryDark = Color(0xFF35486A);
  static const accent      = Color(0xFFC8A45A); // 金（手番・見出し・プレミアム）
  static const danger      = Color(0xFFB3261E); // 朱（投了・残り時間少・成駒と統一）
  static const success     = Color(0xFF5C8A6B); // 松葉（勝利・好手）

  static const textHigh = Color(0xFFF0E9DC); // 生成り（和紙）
  static const textMid  = Color(0xFFB7AC98);
  static const textLow  = Color(0xFF6E6354);

  // ── 余白（8グリッド）─────────────────────────────────────
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;

  // ── 角丸 ──────────────────────────────────────────────────
  static const rCard = 12.0;
  static const rBtn  = 10.0;
  static const rChip = 8.0;

  // ── タイポグラフィスケール ────────────────────────────────
  // 画面ごとにフォントサイズをその場で決め打ちせず、ここから選ぶ。
  // 色は指定しないため、利用側でcolor:のみ上書きして使う。
  static const _fontFamily = null; // システムデフォルトを使用
  static const display = TextStyle(
    fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2,
  );
  static const title = TextStyle(
    fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.bold, height: 1.25,
  );
  static const heading = TextStyle(
    fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3,
  );
  static const body = TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.normal, height: 1.4,
  );
  static const label = TextStyle(
    fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3,
  );
  static const caption = TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.normal, height: 1.3,
  );
  static const overline = TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 1.2, height: 1.2,
  );

  // ── 影 ────────────────────────────────────────────────────
  static List<BoxShadow> glow(Color c, {double blur = 12, double spread = 1}) =>
      [BoxShadow(color: c.withAlpha(70), blurRadius: blur, spreadRadius: spread)];

  static List<BoxShadow> get cardShadow =>
      [const BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))];

  // ── 機能カテゴリ → アクセント色（すべて彩度を落とした和トーン） ──
  static const catPlay   = primary;            // 対局系（藍）
  static const catGrow   = Color(0xFF9B8AC4);  // 育成・実績系（薄紫・藤色）
  static const catSocial = Color(0xFF7FA0BF);  // 交流系（浅葱寄りの藍）
  static const catConfig = Color(0xFF9A9184);  // 設定・課金系（暖色グレー）
}
