import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/install_key.dart';
import 'legal.dart';

/// What this user has seen on this installation:
/// `users/{uid}/installs/{installKey}` = { termsVersion, termsAcceptedAt, tourDone }.
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

  Future<bool> tourDone(String uid, String tour) async {
    final snap = await (await _doc(uid)).get();
    return snap.data()?['tour_$tour'] == true;
  }

  Future<void> markTourDone(String uid, String tour) async =>
      (await _doc(uid)).set({'tour_$tour': true}, SetOptions(merge: true));

  /// Clears the "seen" mark so the tour plays again (About → Take the tour).
  Future<void> resetTour(String uid, String tour) async =>
      (await _doc(uid)).set({'tour_$tour': false}, SetOptions(merge: true));
}
