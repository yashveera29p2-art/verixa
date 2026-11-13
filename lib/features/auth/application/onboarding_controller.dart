import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_profile.dart';
import 'auth_providers.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, AsyncValue<void>>(
        OnboardingController.new);

/// Saves the short onboarding form to `users/{uid}`.
class OnboardingController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Returns true when the profile was saved.
  Future<bool> save({
    required String fullName,
    required UserStatus status,
    required String organisation,
  }) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      state = AsyncError('You’ve been signed out. Please log in again.',
          StackTrace.current);
      return false;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(userRepositoryProvider).saveOnboarding(UserProfile(
            uid: user.uid,
            phone: user.phoneNumber ?? '',
            fullName: fullName,
            status: status,
            organisation: organisation,
          )).timeout(const Duration(seconds: 15));
    });
    return !state.hasError;
  }
}
