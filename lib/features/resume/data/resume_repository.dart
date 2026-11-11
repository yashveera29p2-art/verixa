import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/resume_version.dart';

/// Saved resume versions at `users/{uid}/resumes`.
class ResumeRepository {
  ResumeRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('resumes');

  Stream<List<ResumeVersion>> watchAll(String uid) =>
      _col(uid)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .snapshots()
          .map((q) => q.docs.map(ResumeVersion.fromFirestore).toList());

  Stream<ResumeVersion?> watchOne(String uid, String id) =>
      _col(uid)
          .doc(id)
          .snapshots()
          .map((d) => d.exists ? ResumeVersion.fromFirestore(d) : null);

  /// Creates a version and returns its id. The id is generated locally, so
  /// this returns at once even when the write is still syncing.
  String create(String uid, ResumeVersion v) {
    final ref = _col(uid).doc();
    ref.set(v.toFirestore());
    return ref.id;
  }

  Future<void> save(String uid, ResumeVersion v) =>
      _col(uid).doc(v.id).set(v.toFirestore());

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();
}
