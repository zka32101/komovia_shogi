import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:komovia_core/komovia_core.dart';

/// Friendship CRUD, following komovia_go's `friend_service.dart` design:
/// denormalized relationship docs on both users' own `friends`
/// subcollections (`users/{uid}/friends/{friendUid}`), status-keyed
/// ('pending'/'accepted'/'blocked'), with `requestedBy` distinguishing an
/// incoming request from one the viewer sent, and `blockedBy` so unblocking
/// only ever undoes a block this side actually caused.
class FriendService {
  FriendService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, Object?>> _friendsOf(String uid) =>
      _firestore.collection('users').doc(uid).collection('friends');

  Friendship _fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    return Friendship.fromJson(Map<String, Object?>.from(doc.data() ?? {}));
  }

  Future<String> _displayNameOf(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['displayName'] as String?) ?? 'Player';
  }

  /// Sends (or re-sends) a friend request from [fromUid] to [toUid].
  Future<void> sendRequest(
    String fromUid,
    String fromDisplayName,
    String toUid,
  ) async {
    final toDisplayName = await _displayNameOf(toUid);
    final now = DateTime.now();

    final existing = await _friendsOf(fromUid).doc(toUid).get();
    final requestedBy =
        (existing.data()?['requestedBy'] as String?) ?? fromUid;

    final senderSide = Friendship(
      uid: fromUid,
      friendUid: toUid,
      displayName: toDisplayName,
      status: 'pending',
      requestedBy: requestedBy,
      addedAt: now,
    );
    final recipientSide = Friendship(
      uid: toUid,
      friendUid: fromUid,
      displayName: fromDisplayName,
      status: 'pending',
      requestedBy: requestedBy,
      addedAt: now,
    );

    final batch = _firestore.batch();
    batch.set(_friendsOf(fromUid).doc(toUid), senderSide.toJson());
    batch.set(_friendsOf(toUid).doc(fromUid), recipientSide.toJson());
    await batch.commit();
  }

  Future<void> acceptRequest(String uid, String friendUid) async {
    final mine = await _friendsOf(uid).doc(friendUid).get();
    if (!mine.exists || mine.data()?['status'] != 'pending') return;
    final batch = _firestore.batch();
    batch.update(_friendsOf(uid).doc(friendUid), {'status': 'accepted'});
    batch.update(_friendsOf(friendUid).doc(uid), {'status': 'accepted'});
    await batch.commit();
  }

  /// Deletes both sides of a still-pending request (decline, or cancel by
  /// the original sender). Refuses as a no-op once the relationship is no
  /// longer pending.
  Future<void> rejectRequest(String uid, String friendUid) async {
    final mine = await _friendsOf(uid).doc(friendUid).get();
    if (!mine.exists || mine.data()?['status'] != 'pending') return;
    final batch = _firestore.batch();
    batch.delete(_friendsOf(uid).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(uid));
    await batch.commit();
  }

  Future<void> removeFriend(String uid, String friendUid) async {
    final batch = _firestore.batch();
    batch.delete(_friendsOf(uid).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(uid));
    await batch.commit();
  }

  /// Blocks [friendUid]. Mirrors the block onto the target's own entry
  /// (when one exists) unless they've already independently blocked, so
  /// one person's block never clobbers another's.
  Future<void> blockFriend(String uid, String friendUid) async {
    final displayName = await _displayNameOf(friendUid);
    await _friendsOf(uid).doc(friendUid).set({
      ...Friendship(
        uid: uid,
        friendUid: friendUid,
        displayName: displayName,
        status: 'blocked',
        blockedBy: uid,
        addedAt: DateTime.now(),
      ).toJson(),
    }, SetOptions(merge: true));

    final target = await _friendsOf(friendUid).doc(uid).get();
    if (target.exists && target.data()?['status'] != 'blocked') {
      await _friendsOf(friendUid).doc(uid).update({
        'status': 'blocked',
        'blockedBy': uid,
      });
    }
  }

  /// Undoes a block only when this side caused it.
  Future<void> unblockFriend(String uid, String friendUid) async {
    final mine = await _friendsOf(uid).doc(friendUid).get();
    if (!mine.exists || mine.data()?['status'] != 'blocked') return;
    await _friendsOf(uid).doc(friendUid).delete();

    final target = await _friendsOf(friendUid).doc(uid).get();
    if (target.exists &&
        target.data()?['status'] == 'blocked' &&
        target.data()?['blockedBy'] == uid) {
      await _friendsOf(friendUid).doc(uid).delete();
    }
  }

  /// Whether [uid] is blocked (from [uid]'s own side) with [otherUid].
  Future<bool> isBlocked(String uid, String otherUid) async {
    final doc = await _friendsOf(uid).doc(otherUid).get();
    return doc.data()?['status'] == 'blocked';
  }

  Stream<List<Friendship>> friendsStream(String uid) {
    return _friendsOf(uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }

  Stream<List<Friendship>> pendingStream(String uid) {
    return _friendsOf(uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(_fromDoc).toList());
  }
}
