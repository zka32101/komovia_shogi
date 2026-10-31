import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/skin_preference_service.dart';
import '../src/cosmetics/shogi_skins.dart';

final skinPreferenceServiceProvider =
    Provider<SkinPreferenceService>((ref) => SkinPreferenceService());

/// 選択中の盤スキン id（既定は [defaultBoardSkinId]）。
final selectedBoardSkinIdProvider =
    StateProvider<String>((ref) => defaultBoardSkinId);

/// 選択中の駒セットスキン id（既定は [defaultPieceSkinId]）。
final selectedPieceSkinIdProvider =
    StateProvider<String>((ref) => defaultPieceSkinId);

/// 保存済みの選択を読み込む。未所有・未知の id（カタログから消えた等）は
/// 無視して既定のままにする。
final loadSkinPreferenceProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final saved = await ref.read(skinPreferenceServiceProvider).load();
    if (_ownedIds(kBoardSkins).contains(saved.board)) {
      ref.read(selectedBoardSkinIdProvider.notifier).state = saved.board!;
    }
    if (_ownedIds(kPieceSkins).contains(saved.piece)) {
      ref.read(selectedPieceSkinIdProvider.notifier).state = saved.piece!;
    }
  };
});

final selectBoardSkinProvider = Provider<Future<void> Function(String)>((ref) {
  return (id) async {
    ref.read(selectedBoardSkinIdProvider.notifier).state = id;
    await ref.read(skinPreferenceServiceProvider).setBoardSkin(id);
  };
});

final selectPieceSkinProvider = Provider<Future<void> Function(String)>((ref) {
  return (id) async {
    ref.read(selectedPieceSkinIdProvider.notifier).state = id;
    await ref.read(skinPreferenceServiceProvider).setPieceSkin(id);
  };
});

Set<String> _ownedIds(List<CosmeticItem> items) => {
      for (final i in items)
        if (isSkinOwned(i)) i.id
    };
