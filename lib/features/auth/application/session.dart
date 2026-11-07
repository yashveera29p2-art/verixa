import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/routes.dart';
import '../data/user_repository.dart';

/// Decides where a user should land:
/// signed out → Welcome, no complete profile → Onboarding, otherwise → Home.
Future<String> routeForUser(User? user, UserRepository users) async {
  if (user == null) return AppRoutes.welcome;
  try {
    final profile = await users.fetchProfile(user.uid);
    if (profile == null || !profile.isOnboardingComplete) {
      return AppRoutes.onboarding;
    }
    return AppRoutes.home;
  } catch (_) {
    // Offline with nothing cached: let Home show its own loading/error
    // state rather than wrongly asking for onboarding again.
    return AppRoutes.home;
  }
}
