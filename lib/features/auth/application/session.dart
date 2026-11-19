import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../app/routes.dart';
import '../../recruiter/application/recruiter_providers.dart';
import '../../recruiter/domain/recruiter_models.dart';
import '../domain/user_profile.dart';
import 'auth_providers.dart';

/// Which side of the app the user chose on the Welcome screen before
/// signing in. Only matters for brand-new accounts; existing accounts keep
/// the role saved in their profile.
abstract final class SignInIntent {
  static UserRole role = UserRole.student;
}

/// Decides where a user should land:
/// * signed out → Welcome
/// * Terms not accepted on this installation → Terms
/// * recruiter → setup, waiting for approval, or Find talent
/// * student without a complete profile → Onboarding, otherwise → Home
/// Reads a provider; pass `ref.read` from a provider, notifier or widget.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

Future<String> routeForUser(ProviderReader read, User? user) async {
  if (user == null) return AppRoutes.welcome;
  try {
    final consent = read(consentRepositoryProvider);
    if (!await consent.hasAcceptedTerms(user.uid)) return AppRoutes.terms;

    final profile = await read(userRepositoryProvider).fetchProfile(user.uid);
    final role = profile?.role ?? SignInIntent.role;
    if (role == UserRole.recruiter) {
      final account =
          await read(recruiterRepositoryProvider).fetchAccount(user.uid);
      if (account == null) return AppRoutes.recruiterSetup;
      if (account.status != RecruiterStatus.approved) {
        return AppRoutes.recruiterPending;
      }
      return AppRoutes.recruiterTalent;
    }
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

/// Signs out after forgetting which guides were seen on this installation,
/// so they play again when the person (or someone else) signs in.
Future<void> signOutAndResetGuides(ProviderReader read) async {
  final uid = read(authServiceProvider).currentUser?.uid;
  if (uid != null) await read(consentRepositoryProvider).resetTours(uid);
  await read(authServiceProvider).signOut();
}
