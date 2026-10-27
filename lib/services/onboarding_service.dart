import 'package:shared_preferences/shared_preferences.dart';

/// Whether the player has completed the one-time rules onboarding
/// ([OnboardingScreen]). Stored locally (not Firestore) on purpose: this is
/// a per-device "have I seen this" flag, not account data, and it must work
/// even signed-out/offline — the very first thing a brand-new player does,
/// before `_ensureSignedIn` in `main.dart` necessarily resolves.
class OnboardingService {
  static const _completedKey = 'onboarding_completed';

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }
}
