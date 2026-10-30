import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_core/komovia_core.dart';
import 'package:komovia_shogi/services/user_profile_service.dart';

void main() {
  group('UserProfileService', () {
    test('getProfile returns null for a user with no profile doc at all', () async {
      final service = UserProfileService(firestore: FakeFirebaseFirestore());
      expect(await service.getProfile('u1'), isNull);
    });

    test('setAvatar persists the avatar id', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserProfileService(firestore: firestore);

      await service.setAvatar('u1', 'panda');

      final profile = await service.getProfile('u1');
      expect(profile!.avatarId, 'panda');
    });

    test('setAvatar never clobbers an existing displayName', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserProfileService(firestore: firestore);
      await service.ensureProfile('u1', 'Alice');

      await service.setAvatar('u1', 'owl');

      final profile = await service.getProfile('u1');
      expect(profile!.displayName, 'Alice');
      expect(profile.avatarId, 'owl');
    });

    test('ensureProfile never clobbers an already-chosen avatar', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserProfileService(firestore: firestore);
      await service.setAvatar('u1', 'tiger');

      await service.ensureProfile('u1', 'Alice');

      final profile = await service.getProfile('u1');
      expect(profile!.avatarId, 'tiger');
      expect(profile.displayName, 'Alice');
    });

    test('a profile with no avatarId resolves to the default icon via '
        'avatarIconById', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserProfileService(firestore: firestore);
      await service.ensureProfile('u1', 'Alice');

      final profile = await service.getProfile('u1');
      expect(avatarIconById(profile!.avatarId), defaultAvatarIcon);
    });

    test('a user that never existed at all also resolves to the default '
        'icon, never throwing', () async {
      final service = UserProfileService(firestore: FakeFirebaseFirestore());
      final profile = await service.getProfile('nobody');
      expect(avatarIconById(profile?.avatarId), defaultAvatarIcon);
    });

    test('profileStream emits updates as the avatar changes', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserProfileService(firestore: firestore);

      final emissions = <String?>[];
      final sub = service.profileStream('u1').listen((p) {
        emissions.add(p?.avatarId);
      });

      await Future<void>.delayed(Duration.zero);
      await service.setAvatar('u1', 'lion');
      await Future<void>.delayed(Duration.zero);
      await service.setAvatar('u1', 'crane');
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions, [null, 'lion', 'crane']);
    });
  });
}
