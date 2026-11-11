import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/profile_repository.dart';
import '../domain/profile_data.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(firestoreProvider)),
);

/// Live profile of the signed-in user (null when signed out).
final profileDataProvider = StreamProvider<ProfileData?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watch(user.uid);
});

final profileSaveControllerProvider =
    NotifierProvider<ProfileSaveController, AsyncValue<void>>(
        ProfileSaveController.new);

/// Runs a section save and exposes loading / error state to the editor.
class ProfileSaveController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// [write] receives the signed-in uid and the repository.
  /// Returns true when the save succeeded.
  Future<bool> save(
    Future<void> Function(String uid, ProfileRepository repo) write,
  ) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      state = AsyncError('signed-out', StackTrace.current);
      return false;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => write(uid, ref.read(profileRepositoryProvider)));
    return !state.hasError;
  }

  void reset() => state = const AsyncData(null);
}
