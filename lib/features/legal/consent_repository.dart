import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/install_key.dart';
import 'legal.dart';

/// What this user has seen on this installation:
/// `users/{uid}/installs/{installKey}` = { termsVersion, termsAcceptedAt, tours: {name: true} }.
class ConsentRepository {
  ConsentRepository(this._db);

  final FirebaseFirestore _db;

  Future<DocumentReference<Map<String, dynamic>>> _doc(String uid) async =>
      _db.collection('users').doc(uid).collection('installs').doc(await installKey());

  /// True if the current Terms were accepted on this installation.
  Future<bool> hasAcceptedTerms(String uid) async {
    final snap = await (await _doc(uid)).get();
    final v = (snap.data()?['termsVersion'] as num?)?.toInt() ?? 0;
    return v >= Legal.termsVersion;
  }

  Future<void> acceptTerms(String uid) async => (await _doc(uid)).set({
        'termsVersion': Legal.termsVersion,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Guides already seen on this installation: { tours: { jobs: true, … } }.
  Future<bool> tourDone(String uid, String tour) async {
    final data = (await (await _doc(uid)).get()).data();
    return (data?['tours'] as Map?)?[tour] == true || data?['tour_$tour'] == true;
  }

  Future<void> markTourDone(String uid, String tour) async =>
      (await _doc(uid)).set({
        'tours': {tour: true},
      }, SetOptions(merge: true));

  /// Forgets every guide on this installation, so they all play again
  /// (after signing out and in again).
  /// The Terms acceptance is kept.
  Future<void> resetTours(String uid) async {
    try {
      await (await _doc(uid)).update({
        'tours': <String, bool>{}, // update() replaces the whole map
        'tour_student': false,
        'tour_recruiter': false,
      }).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Nothing saved yet on this installation, or offline: nothing to reset.
    }
  }
}
