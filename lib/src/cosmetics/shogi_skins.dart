import 'package:flutter/widgets.dart';
import 'package:komovia_core/komovia_core.dart';

/// 盤スキン・駒セットスキンのカタログと描画パラメータ。
///
/// カタログ自体は komovia_core の [CosmeticItem]（所有判定の共通ロジック）
/// で表し、実際の見た目（色）はこのアプリ固有の [BoardSkinStyle] /
/// [PieceSkinStyle] で id に紐付ける。
///
/// 課金について: このアプリにはまだ購入・サブスクリプション基盤
/// （in_app_purchase / Entitlement の永続化 / レシート検証）が存在しない。
/// そのため現時点では全員無料（[CosmeticItem.isFreeForAll]）のスキンだけを
/// 有効化しており、有料・サブスク同梱スキンは下のTODOコメントとして
/// カタログ定義だけ用意してある。購入基盤ができたら該当行のコメントを外し、
/// [isSkinOwned] に実際のサブスク状態・購入済み productId を渡すこと。
const kBoardSkinCategory = 'boardSkin';
const kPieceSkinCategory = 'pieceSkin';

class BoardSkinStyle {
  const BoardSkinStyle({
    required this.cellColor,
    required this.cellBorder,
    required this.outerBorder,
    required this.handBarColor,
  });

  final Color cellColor;
  final Color cellBorder;
  final Color outerBorder;
  final Color handBarColor;
}

class PieceSkinStyle {
  const PieceSkinStyle({
    required this.fill,
    required this.border,
    required this.labelColor,
  });

  final Color fill;
  final Color border;

  /// 成駒以外の駒文字の色（成駒は従来どおり朱色）。
  final Color labelColor;
}

const defaultBoardSkinId = 'kaya';
const defaultPieceSkinId = 'classic';

const List<CosmeticItem> kBoardSkins = [
  CosmeticItem(id: 'kaya', category: kBoardSkinCategory, name: '榧（標準）'),
  CosmeticItem(id: 'shiraki', category: kBoardSkinCategory, name: '白木'),
  CosmeticItem(id: 'matcha', category: kBoardSkinCategory, name: '抹茶'),
  // TODO(monetization): 購入基盤ができたら有効化する。
  // CosmeticItem(id: 'kaya_dark', category: kBoardSkinCategory, name: '本榧・濃',
  //     includedWithSubscription: true,
  //     iapProductId: 'komovia_shogi_board_kaya_dark'),
  // CosmeticItem(id: 'urushi', category: kBoardSkinCategory, name: '漆塗り',
  //     iapProductId: 'komovia_shogi_board_urushi'),
  // CosmeticItem(id: 'mono', category: kBoardSkinCategory, name: 'モノトーン',
  //     includedWithSubscription: true,
  //     iapProductId: 'komovia_shogi_board_mono'),
];

const List<CosmeticItem> kPieceSkins = [
  CosmeticItem(id: 'classic', category: kPieceSkinCategory, name: '黄楊（標準）'),
  CosmeticItem(id: 'ivory', category: kPieceSkinCategory, name: '象牙色'),
  CosmeticItem(id: 'amber', category: kPieceSkinCategory, name: '飴色'),
  // TODO(monetization): 購入基盤ができたら有効化する。
  // CosmeticItem(id: 'shimanto', category: kPieceSkinCategory, name: '島黄楊・書体',
  //     iapProductId: 'komovia_shogi_piece_shimanto'),
  // CosmeticItem(id: 'kuro', category: kPieceSkinCategory, name: '黒檀・金文字',
  //     includedWithSubscription: true,
  //     iapProductId: 'komovia_shogi_piece_kuro'),
];

const Map<String, BoardSkinStyle> _boardStyles = {
  // 従来の MiniBoardWidget の配色そのもの。
  'kaya': BoardSkinStyle(
    cellColor: Color(0xFFDEB887),
    cellBorder: Color(0xFF7A4E2B),
    outerBorder: Color(0xFF4A2E0A),
    handBarColor: Color(0xFFC8A46A),
  ),
  'shiraki': BoardSkinStyle(
    cellColor: Color(0xFFF2E3C0),
    cellBorder: Color(0xFF9C7A50),
    outerBorder: Color(0xFF6B5030),
    handBarColor: Color(0xFFE0CBA0),
  ),
  'matcha': BoardSkinStyle(
    cellColor: Color(0xFFB9C9A0),
    cellBorder: Color(0xFF55663E),
    outerBorder: Color(0xFF34401F),
    handBarColor: Color(0xFFA3B588),
  ),
};

const Map<String, PieceSkinStyle> _pieceStyles = {
  'classic': PieceSkinStyle(
    fill: Color(0xFFF4DDA6),
    border: Color(0xFFC49A4E),
    labelColor: Color(0xFF2C1A0A),
  ),
  'ivory': PieceSkinStyle(
    fill: Color(0xFFFFF8E6),
    border: Color(0xFFB8A888),
    labelColor: Color(0xFF1A1A1A),
  ),
  'amber': PieceSkinStyle(
    fill: Color(0xFFE2B26A),
    border: Color(0xFF8A5A22),
    labelColor: Color(0xFF3A1E05),
  ),
};

/// 未知・未所有・null の id は既定スキンにフォールバックする。
BoardSkinStyle boardSkinStyleById(String? id) =>
    _boardStyles[id] ?? _boardStyles[defaultBoardSkinId]!;

PieceSkinStyle pieceSkinStyleById(String? id) =>
    _pieceStyles[id] ?? _pieceStyles[defaultPieceSkinId]!;

/// 所有判定。購入基盤ができるまでは常に「未加入・購入なし」として判定する
/// （＝無料スキンのみ所有扱い）。
bool isSkinOwned(
  CosmeticItem item, {
  bool hasActiveSubscription = false,
  Set<String> purchasedProductIds = const {},
}) =>
    item.isOwnedBy(
      hasActiveSubscription: hasActiveSubscription,
      purchasedProductIds: purchasedProductIds,
    );

/// アプリ全体の盤面描画に現在のスキンを渡す。`MiniBoardWidget` はこれが
/// 無ければ既定スキンで描画する（テスト等で未設定でも従来の見た目）。
class ShogiSkinScope extends InheritedWidget {
  const ShogiSkinScope({
    super.key,
    required this.board,
    required this.piece,
    required super.child,
  });

  final BoardSkinStyle board;
  final PieceSkinStyle piece;

  static ShogiSkinScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShogiSkinScope>();

  @override
  bool updateShouldNotify(ShogiSkinScope old) =>
      old.board != board || old.piece != piece;
}
