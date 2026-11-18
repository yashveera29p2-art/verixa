import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/recruiter_models.dart';

/// Recruiter accounts, posted jobs, opted-in candidates and shortlists.
class RecruiterRepository {
  RecruiterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _recruiters =>
      _db.collection('recruiters');
  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');
  CollectionReference<Map<String, dynamic>> get _candidates =>
      _db.collection('candidates');

  // ── Recruiter account ─────────────────────────────────────────────────

  Stream<RecruiterAccount?> watchAccount(String uid) =>
      _recruiters.doc(uid).snapshots().map(RecruiterAccount.fromDoc);

  Future<RecruiterAccount?> fetchAccount(String uid) async =>
      RecruiterAccount.fromDoc(await _recruiters.doc(uid).get());

  /// Creates the account request (status "pending") and marks the user as
  /// a recruiter in `users/{uid}`.
  Future<void> requestAccount(RecruiterAccount a) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch()
      ..set(_db.collection('users').doc(a.uid), {
        'uid': a.uid,
        'phone': a.phone,
        'fullName': a.fullName.trim(),
        // Recruiters are working professionals; keeps old app versions happy.
        'status': 'working_professional',
        'organisation': a.company.trim(),
        'role': 'recruiter',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true))
      ..set(_recruiters.doc(a.uid), {
        'fullName': a.fullName.trim(),
        'company': a.company.trim(),
        'designation': a.designation.trim(),
        'workEmail': a.workEmail.trim(),
        'phone': a.phone,
        'status': 'pending',
        'createdAt': now,
      });
    await batch.commit().timeout(const Duration(seconds: 15));
  }

  // ── Admin ─────────────────────────────────────────────────────────────

  Stream<List<RecruiterAccount>> watchRequests() => _recruiters
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(RecruiterAccount.fromDoc).nonNulls.toList());

  Future<void> setStatus(String uid, RecruiterStatus status) =>
      _recruiters.doc(uid).update({'status': status.name});

  // ── Jobs ──────────────────────────────────────────────────────────────

  Future<void> postJob(PostedJob job) => _jobs
      .add({...job.toFirestore(), 'createdAt': FieldValue.serverTimestamp()})
      .timeout(const Duration(seconds: 15));

  Stream<List<PostedJob>> watchMyJobs(String uid) => _jobs
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(PostedJob.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  /// Visible jobs for students, newest first.
  Future<List<PostedJob>> fetchOpenJobs() async {
    final s = await _jobs.where('hidden', isEqualTo: false).limit(60).get();
    return s.docs.map(PostedJob.fromDoc).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  }

  Stream<List<PostedJob>> watchAllJobs() => _jobs
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(PostedJob.fromDoc).toList());

  Future<void> setJobHidden(String id, bool hidden) =>
      _jobs.doc(id).update({'hidden': hidden});

  Future<void> deleteJob(String id) => _jobs.doc(id).delete();

  // ── Candidates ────────────────────────────────────────────────────────

  Future<List<CandidateCard>> fetchCandidates() async {
    final s = await _candidates.limit(60).get();
    return s.docs.map(CandidateCard.fromDoc).toList();
  }

  // ── Shortlist (recruiters/{uid}/shortlist/{candidateUid}) ─────────────

  CollectionReference<Map<String, dynamic>> _shortlist(String uid) =>
      _recruiters.doc(uid).collection('shortlist');

  Stream<Set<String>> watchShortlistIds(String uid) =>
      _shortlist(uid).snapshots().map((s) => s.docs.map((d) => d.id).toSet());

  Stream<List<Map<String, dynamic>>> watchShortlist(String uid) =>
      _shortlist(uid).orderBy('addedAt', descending: true).snapshots().map(
            (s) => [for (final d in s.docs) {'uid': d.id, ...d.data()}],
          );

  Future<void> toggleShortlist(String uid, CandidateCard c, bool add,
      {String? jobTitle}) {
    final ref = _shortlist(uid).doc(c.uid);
    if (!add) return ref.delete();
    return ref.set({
      'fullName': c.fullName,
      'headline': c.headline,
      'jobTitle': jobTitle ?? '',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }
}
