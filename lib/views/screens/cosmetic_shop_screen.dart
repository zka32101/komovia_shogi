import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../../l10n/app_localizations.dart';
import '../../src/cosmetics/shogi_skins.dart';
import '../../src/mini_board_widget.dart';
import '../../src/piece.dart';
import '../../viewmodels/index.dart';

/// 盤スキン・駒セットスキンの選択画面。
///
/// カタログは全員無料のスキンと、買い切りプラン購入者限定のスキン
/// （`shogi_skins.dart` 参照）。スキン単体の購入ボタンはまだ出さない
/// （限定スキンは買い切りプランの特典として付与される）。
class CosmeticShopScreen extends ConsumerWidget {
  const CosmeticShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final boardId = ref.watch(selectedBoardSkinIdProvider);
    final pieceId = ref.watch(selectedPieceSkinIdProvider);
    final isOwned = ref.watch(skinOwnershipProvider);

    Widget section(
      String label,
      List<CosmeticItem> items,
      String selectedId,
      ShogiSkinScope Function(CosmeticItem, Widget) previewScope,
      Future<void> Function(String) onSelect,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final item in items)
            _SkinTile(
              key: ValueKey('skin-${item.category}-${item.id}'),
              item: item,
              selected: item.id == selectedId,
              owned: isOwned(item),
              preview: previewScope(item, const _SkinPreview()),
              selectedLabel: l10n.skinSelectedLabel,
              lockedLabel: l10n.skinLockedLabel,
              onTap: () => onSelect(item.id),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cosmeticShopTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section(
            l10n.boardSkinSectionLabel,
            kBoardSkins,
            boardId,
            (item, child) => ShogiSkinScope(
              board: boardSkinStyleById(item.id),
              piece: pieceSkinStyleById(pieceId),
              child: child,
            ),
            ref.read(selectBoardSkinProvider),
          ),
          section(
            l10n.pieceSkinSectionLabel,
            kPieceSkins,
            pieceId,
            (item, child) => ShogiSkinScope(
              board: boardSkinStyleById(boardId),
              piece: pieceSkinStyleById(item.id),
              child: child,
            ),
            ref.read(selectPieceSkinProvider),
          ),
        ],
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    super.key,
    required this.item,
    required this.selected,
    required this.owned,
    required this.preview,
    required this.selectedLabel,
    required this.lockedLabel,
    required this.onTap,
  });

  final CosmeticItem item;
  final bool selected;
  final bool owned;
  final Widget preview;
  final String selectedLabel;
  final String lockedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: SizedBox(width: 56, height: 56, child: preview),
        title: Text(item.name),
        trailing: selected
            ? Chip(label: Text(selectedLabel))
            : owned
                ? null
                : Chip(
                    avatar: const Icon(Icons.lock, size: 16),
                    label: Text(lockedLabel),
                  ),
        // 未所有スキンは購入基盤ができるまで選択不可。
        onTap: owned ? onTap : null,
      ),
    );
  }
}

/// 盤の一部と数枚の駒だけを描くプレビュー（3×3 を 9×9 盤の角に配置）。
class _SkinPreview extends StatelessWidget {
  const _SkinPreview();

  static final List<List<Piece?>> _board = () {
    final b = List.generate(9, (_) => List<Piece?>.filled(9, null));
    b[0][0] = const Piece(PieceType.lance, false);
    b[1][1] = const Piece(PieceType.king, true);
    b[2][0] = const Piece(PieceType.gold, true);
    b[2][2] = const Piece(PieceType.pawn, true);
    return b;
  }();

  @override
  Widget build(BuildContext context) {
    // 9×9盤を3倍に拡大して左上3×3だけを見せる。
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 168,
        maxWidth: 168,
        minHeight: 168,
        maxHeight: 168,
        child: MiniBoardWidget(board: _board, showLabels: false, size: 168),
      ),
    );
  }
}
