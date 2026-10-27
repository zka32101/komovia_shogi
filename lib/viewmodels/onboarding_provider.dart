import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/onboarding_service.dart';

final onboardingServiceProvider = Provider<OnboardingService>(
  (ref) => OnboardingService(),
);

/// Whether the one-time rules onboarding ([OnboardingScreen]) has already
/// been completed on this device. `autoDispose` so `_RootScreen` re-checks
/// it fresh each cold start rather than caching a stale `false` across app
/// restarts within the same process (irrelevant in production, but keeps
/// tests that override this provider from leaking state between them).
final hasCompletedOnboardingProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  return ref.read(onboardingServiceProvider).hasCompletedOnboarding();
});

/// Marks onboarding complete and invalidates [hasCompletedOnboardingProvider]
/// so `_RootScreen` picks up the change immediately (it's read once at
/// startup via `ref.watch`, which re-evaluates on invalidation).
final completeOnboardingProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(onboardingServiceProvider).markOnboardingCompleted();
    ref.invalidate(hasCompletedOnboardingProvider);
  };
});
