import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/user_profile.dart';
import '../src/cosmetics/avatar_frames.dart';
import '../services/user_profile_service.dart';
import 'auth_provider.dart';
import 'leaderboard_provider.dart';
import 'purchase_provider.dart';

final userProfileServiceProvider = Provider<UserProfileService>(
  (ref) => UserProfileService(),
);

final userProfileStreamProvider =
    StreamProvider.family<UserProfile?, String>(
      (ref, uid) => ref.watch(userProfileServiceProvider).profileStream(uid),
    );

/// The resolved [AvatarIcon] for [uid] — always a real icon, never null,
/// falling back to [defaultAvatarIcon] while loading or for a user who
/// never picked one (including every account that existed before this
/// feature shipped).
final userAvatarIconProvider = Provider.family<AvatarIcon, String>((
  ref,
  uid,
) {
  final profile = ref.watch(userProfileStreamProvider(uid)).value;
  return avatarIconById(profile?.avatarId);
});

final setUserAvatarProvider = Provider(
  (ref) => (String uid, String avatarId) =>
      ref.read(userProfileServiceProvider).setAvatar(uid, avatarId),
);

final ensureUserProfileProvider = Provider(
  (ref) => (String uid, String displayName) =>
      ref.read(userProfileServiceProvider).ensureProfile(uid, displayName),
);

final setUserFrameProvider = Provider(
  (ref) => (String uid, String? frameId) =>
      ref.read(userProfileServiceProvider).setFrame(uid, frameId),
);

/// [uid]の解放済みフレームid。ランキングエントリー（AI対局の対局数・
/// 勝数・レーティング）から毎回導出する。読み込み中・未対局は空集合。
final unlockedAvatarFrameIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, uid) async {
      final entry = await ref.watch(leaderboardServiceProvider).getEntry(uid);
      // 購入で付与されたフレームは本人専用の権利ドキュメントにあるため、
      // 自分自身のときだけ合算する（他人の権利ドキュメントは読めない）。
      String? me;
      try {
        me = ref.watch(currentUidProvider);
      } catch (_) {
        me = null;
      }
      final purchased = me == uid
          ? (await ref.watch(userEntitlementsProvider.future)).unlockedFrameIds
          : const <String>{};
      return unlockedAvatarFrameIds(entry, purchasedFrameIds: purchased);
    });

/// 表示用に解決した[uid]の選択フレーム。未選択・未解放・読み込み中はnull。
final userAvatarFrameProvider = Provider.family<AvatarFrame?, String>((
  ref,
  uid,
) {
  final profile = ref.watch(userProfileStreamProvider(uid)).value;
  final unlocked =
      ref.watch(unlockedAvatarFrameIdsProvider(uid)).value ?? const {};
  return resolveDisplayedFrame(profile?.frameId, unlocked);
});
