import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';

/// Reads and writes the user's profile document at `users/{uid}`.
class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// The profile, or null if onboarding hasn't been completed yet.
  Future<UserProfile?> fetchProfile(String uid) async {
    final snapshot = await _doc(uid).get();
    return UserProfile.fromFirestore(snapshot);
  }

  Stream<UserProfile?> watchProfile(String uid) =>
      _doc(uid).snapshots().map(UserProfile.fromFirestore);

  /// Saves the onboarding answers. Creates the document the first time,
  /// and only updates the onboarding fields afterwards.
  Future<void> saveOnboarding(UserProfile profile) async {
    final ref = _doc(profile.uid);
    final existing = await ref.get();
    final now = FieldValue.serverTimestamp();
    if (existing.exists) {
      await ref.update({...profile.toFirestore(), 'updatedAt': now});
    } else {
      await ref.set({
        ...profile.toFirestore(),
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }
}
