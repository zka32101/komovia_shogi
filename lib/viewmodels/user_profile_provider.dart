import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

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
