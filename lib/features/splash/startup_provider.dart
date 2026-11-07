import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/application/auth_providers.dart';
import '../auth/application/session.dart';

/// Decides where the app goes after the splash. Read as soon as the splash
/// starts, so the answer is usually ready before the animation finishes.
///
/// Waits for Firebase to restore any saved session, then:
/// signed out → Welcome, profile incomplete → Onboarding, else → Home.
final startupDestinationProvider = FutureProvider<String>((ref) async {
  final auth = ref.read(authServiceProvider);
  final user = await auth.authStateChanges().first;
  return routeForUser(user, ref.read(userRepositoryProvider));
});
