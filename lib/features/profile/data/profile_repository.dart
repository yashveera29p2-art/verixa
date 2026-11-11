import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_data.dart';

/// Reads and writes profile sections inside `users/{uid}`.
///
/// Each section is one nested field (contact, statusDetails, ...), saved
/// on its own so editing one step never overwrites another.
class ProfileRepository {
  ProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<ProfileData?> watch(String uid) => _doc(uid).snapshots().map(
        (snap) =>
            snap.data() == null ? null : ProfileData.fromFirestore(snap.data()!),
      );

  Future<void> _update(String uid, Map<String, dynamic> fields) =>
      _doc(uid).update({...fields, 'updatedAt': FieldValue.serverTimestamp()});

  /// Also updates the top-level name used by Home's greeting.
  Future<void> saveContact(String uid, ContactInfo contact) => _update(uid, {
        'contact': contact.toMap(),
        'fullName': contact.fullName.trim(),
      });

  /// Also keeps the onboarding fields (status, organisation) in sync.
  Future<void> saveStatus(String uid, StatusDetails details) => _update(uid, {
        'statusDetails': details.toMap(),
        'status': details.status.id,
        'organisation': details.organisation.trim(),
      });

  Future<void> saveEducation(String uid, EducationHistory education) =>
      _update(uid, {'education': education.toMap()});

  Future<void> saveCareerGoal(String uid, CareerGoal goal) =>
      _update(uid, {'careerGoal': goal.toMap()});

  Future<void> saveExperience(String uid, ExperienceHistory experience) =>
      _update(uid, {'experience': experience.toMap()});

  Future<void> saveProjects(String uid, List<ProjectEntry> projects) =>
      _update(uid, {'projects': projects.map((p) => p.toMap()).toList()});

  Future<void> saveSkills(String uid, SkillSet skills) =>
      _update(uid, {'skills': skills.toMap()});

  Future<void> saveExtras(String uid, Extras extras) =>
      _update(uid, {'extras': extras.toMap()});

  /// Saves several sections in one write (used by resume import).
  /// Sections left null are not touched.
  Future<void> saveSections(
    String uid, {
    ContactInfo? contact,
    StatusDetails? status,
    EducationHistory? education,
    CareerGoal? careerGoal,
    ExperienceHistory? experience,
    List<ProjectEntry>? projects,
    SkillSet? skills,
    Extras? extras,
  }) {
    final fields = <String, dynamic>{
      if (contact != null) ...{
        'contact': contact.toMap(),
        if (contact.fullName.trim().length >= 2)
          'fullName': contact.fullName.trim(),
      },
      if (status != null) ...{
        'statusDetails': status.toMap(),
        'status': status.status.id,
        if (status.organisation.trim().isNotEmpty)
          'organisation': status.organisation.trim(),
      },
      if (education != null) 'education': education.toMap(),
      if (careerGoal != null) 'careerGoal': careerGoal.toMap(),
      if (experience != null) 'experience': experience.toMap(),
      if (projects != null)
        'projects': projects.map((p) => p.toMap()).toList(),
      if (skills != null) 'skills': skills.toMap(),
      if (extras != null) 'extras': extras.toMap(),
    };
    if (fields.isEmpty) return Future.value();
    return _update(uid, fields);
  }
}
