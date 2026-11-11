import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_service.dart';
import '../data/user_repository.dart';
import '../domain/user_profile.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authServiceProvider =
    Provider<AuthService>((ref) => AuthService(ref.watch(firebaseAuthProvider)));

final userRepositoryProvider =
    Provider<UserRepository>((ref) => UserRepository(ref.watch(firestoreProvider)));

/// The signed-in Firebase user, or null.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// The signed-in user right now.
///
/// Uses the auth stream once it has emitted, and Firebase's synchronous
/// `currentUser` before that. Reading only `authStateProvider.value` would
/// briefly report "signed out" the first time it's read, making profile
/// providers emit null for a signed-in user.
final currentUserProvider = Provider<User?>((ref) {
  final state = ref.watch(authStateProvider);
  return state.hasValue
      ? state.value
      : ref.watch(authServiceProvider).currentUser;
});

/// Live profile of the signed-in user (null if signed out or not onboarded).
final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchProfile(user.uid);
});
