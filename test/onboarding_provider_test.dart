import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komovia_shogi/viewmodels/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('hasCompletedOnboardingProvider', () {
    test('is false before onboarding has ever been completed', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(hasCompletedOnboardingProvider.future), isFalse);
    });

    test('becomes true after completeOnboardingProvider is called', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(await container.read(hasCompletedOnboardingProvider.future), isFalse);

      await container.read(completeOnboardingProvider)();

      expect(await container.read(hasCompletedOnboardingProvider.future), isTrue);
    });

    test('a fresh container sees a completion persisted by an earlier one', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(completeOnboardingProvider)();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(await second.read(hasCompletedOnboardingProvider.future), isTrue);
    });
  });
}
