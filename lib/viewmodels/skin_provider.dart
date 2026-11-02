import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/skin_preference_service.dart';
import '../src/cosmetics/shogi_skins.dart';
import 'purchase_provider.dart';

final skinPreferenceServiceProvider =
    Provider<SkinPreferenceService>((ref) => SkinPreferenceService());

/// 選択中の盤スキン id（既定は [defaultBoardSkinId]）。
final selectedBoardSkinIdProvider =
    StateProvider<String>((ref) => defaultBoardSkinId);

/// 選択中の駒セットスキン id（既定は [defaultPieceSkinId]）。
final selectedPieceSkinIdProvider =
    StateProvider<String>((ref) => defaultPieceSkinId);

/// 現在のユーザーの権利でスキン所有を判定する関数。
final skinOwnershipProvider = Provider<bool Function(CosmeticItem)>((ref) {
  final premium = ref.watch(isPremiumActiveProvider);
  final lifetime = ref.watch(isLifetimePurchaserProvider);
  return (item) => isSkinOwned(item,
      hasActiveSubscription: premium, isLifetimePurchaser: lifetime);
});

/// 保存済みの選択を読み込む。未所有・未知の id（カタログから消えた等）は
/// 無視して既定のままにする。
final loadSkinPreferenceProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final saved = await ref.read(skinPreferenceServiceProvider).load();
    // 買い切り限定スキンの判定のため、権利の読み込みを待つ。
    try {
      await ref.read(userEntitlementsProvider.future);
    } catch (_) {}
    final owned = ref.read(skinOwnershipProvider);
    if (_ownedIds(kBoardSkins, owned).contains(saved.board)) {
      ref.read(selectedBoardSkinIdProvider.notifier).state = saved.board!;
    }
    if (_ownedIds(kPieceSkins, owned).contains(saved.piece)) {
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

Set<String> _ownedIds(
        List<CosmeticItem> items, bool Function(CosmeticItem) owned) =>
    {
      for (final i in items)
        if (owned(i)) i.id
    };
