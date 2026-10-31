/// A user's own profile document (`users/{uid}`), separate from the
/// per-relationship [Friendship] data komovia_core provides (each
/// [Friendship] is a denormalized copy on someone *else's* subcollection,
/// not the owner's own profile).
///
/// Kept intentionally small: just the fields this app actually persists
/// about a user's own account today (`displayName`, `avatarId`). New
/// fields should be added the same way `avatarId` was here — nullable,
/// with a safe default when absent — so old documents never break.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName,
    this.avatarId,
    this.frameId,
  });

  final String uid;

  /// Denormalized elsewhere too (e.g. `Friendship.displayName`), but this
  /// is the single source of truth `FriendService._displayNameOf` reads
  /// from. Null for a profile document that was never written.
  final String? displayName;

  /// A [kAvatarIcons] id, or null if the user never picked one. Always
  /// resolve for display via `avatarIconById(avatarId)` (from
  /// `package:komovia_core`), which safely falls back to the default
  /// icon for null/empty/unknown ids — never read this field directly
  /// for display.
  final String? avatarId;

  /// A `kAvatarFrames` id, or null for no frame. Always resolve for
  /// display via `resolveDisplayedFrame`, which also hides a frame that
  /// is (no longer) unlocked.
  final String? frameId;

  UserProfile copyWith({
    String? displayName,
    Object? avatarId = _unset,
    Object? frameId = _unset,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      avatarId: avatarId == _unset ? this.avatarId : avatarId as String?,
      frameId: frameId == _unset ? this.frameId : frameId as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'avatarId': avatarId,
    'frameId': frameId,
  };

  factory UserProfile.fromJson(String uid, Map<String, Object?> json) {
    return UserProfile(
      uid: uid,
      displayName: json['displayName'] as String?,
      avatarId: json['avatarId'] as String?,
      frameId: json['frameId'] as String?,
    );
  }
}

/// Sentinel distinguishing "not passed" from an explicit `null` in
/// [UserProfile.copyWith], matching komovia_core's `Friendship.copyWith`
/// convention.
const Object _unset = Object();
