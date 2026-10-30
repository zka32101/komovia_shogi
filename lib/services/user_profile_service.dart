import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Reads/writes a user's own profile doc (`users/{uid}`) — today just
/// `displayName`/`avatarId`. Following [FriendService]'s constructor-DI
/// pattern so this is directly testable with `fake_cloud_firestore`.
class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, Object?>> _doc(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(uid, doc.data() ?? {});
  }

  Stream<UserProfile?> profileStream(String uid) {
    return _doc(uid).snapshots().map(
      (doc) =>
          doc.exists ? UserProfile.fromJson(uid, doc.data() ?? {}) : null,
    );
  }

  /// Persists the chosen avatar. Merge-set so this never clobbers
  /// `displayName` (or any other field) even if the profile doc doesn't
  /// exist yet.
  Future<void> setAvatar(String uid, String avatarId) {
    return _doc(uid).set({'avatarId': avatarId}, SetOptions(merge: true));
  }

  /// Makes sure a profile doc exists with at least [displayName] set —
  /// the write `FriendService._displayNameOf` has always depended on but
  /// that, before this feature, nothing in the app ever actually
  /// performed. Merge-set, so it never overwrites an `avatarId` the user
  /// already picked.
  Future<void> ensureProfile(String uid, String displayName) {
    return _doc(uid).set({
      'displayName': displayName,
    }, SetOptions(merge: true));
  }
}
