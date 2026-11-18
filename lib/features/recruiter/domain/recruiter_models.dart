import 'package:cloud_firestore/cloud_firestore.dart';

/// A recruiter's account request at `recruiters/{uid}`. The Verixa team
/// approves it before the recruiter can search students or post jobs.
enum RecruiterStatus {
  pending('Pending approval'),
  approved('Approved'),
  rejected('Not approved');

  const RecruiterStatus(this.label);
  final String label;

  static RecruiterStatus fromId(String? id) => values.firstWhere(
        (v) => v.name == id,
        orElse: () => RecruiterStatus.pending,
      );
}

class RecruiterAccount {
  const RecruiterAccount({
    required this.uid,
    required this.fullName,
    required this.company,
    required this.designation,
    required this.workEmail,
    required this.phone,
    this.status = RecruiterStatus.pending,
    this.createdAt,
  });

  final String uid;
  final String fullName;
  final String company;
  final String designation;
  final String workEmail;
  final String phone;
  final RecruiterStatus status;
  final DateTime? createdAt;

  static RecruiterAccount? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    return RecruiterAccount(
      uid: doc.id,
      fullName: d['fullName'] as String? ?? '',
      company: d['company'] as String? ?? '',
      designation: d['designation'] as String? ?? '',
      workEmail: d['workEmail'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      status: RecruiterStatus.fromId(d['status'] as String?),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Full-time, internship or part-time.
enum JobType {
  fullTime('full_time', 'Full-time'),
  internship('internship', 'Internship'),
  partTime('part_time', 'Part-time');

  const JobType(this.id, this.label);
  final String id;
  final String label;

  static JobType fromId(String? id) =>
      values.firstWhere((v) => v.id == id, orElse: () => JobType.fullTime);
}

/// A job a recruiter posted on Verixa, at `jobs/{id}`.
class PostedJob {
  const PostedJob({
    required this.id,
    required this.ownerUid,
    required this.company,
    required this.title,
    required this.location,
    required this.type,
    required this.payMinLpa,
    required this.payMaxLpa,
    required this.description,
    required this.skills,
    this.wantedTraits = const {},
    this.createdAt,
    this.hidden = false,
  });

  final String id;
  final String ownerUid;
  final String company;
  final String title;
  final String location;
  final JobType type;

  /// Yearly pay in lakhs (LPA); 0 and 0 = unpaid.
  final double payMinLpa;
  final double payMaxLpa;
  final String description;
  final List<String> skills;

  /// Work-style traits the recruiter values (trait id → 0..1).
  final Map<String, double> wantedTraits;
  final DateTime? createdAt;
  final bool hidden;

  bool get unpaid => payMaxLpa <= 0;

  String get payText {
    if (unpaid) return 'Unpaid';
    String f(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return payMinLpa > 0 && payMinLpa != payMaxLpa
        ? '₹${f(payMinLpa)}–${f(payMaxLpa)} LPA'
        : '₹${f(payMaxLpa)} LPA';
  }

  /// Text the matcher reads.
  String get matchText => [
        title,
        description,
        if (skills.isNotEmpty) 'Required: ${skills.join(', ')}.',
      ].join('\n');

  Map<String, dynamic> toFirestore() => {
        'ownerUid': ownerUid,
        'company': company.trim(),
        'title': title.trim(),
        'location': location.trim(),
        'type': type.id,
        'payMinLpa': payMinLpa,
        'payMaxLpa': payMaxLpa,
        'description': description.trim(),
        'skills': skills,
        'wantedTraits': wantedTraits,
        'hidden': hidden,
      };

  static PostedJob fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PostedJob(
      id: doc.id,
      ownerUid: d['ownerUid'] as String? ?? '',
      company: d['company'] as String? ?? '',
      title: d['title'] as String? ?? '',
      location: d['location'] as String? ?? '',
      type: JobType.fromId(d['type'] as String?),
      payMinLpa: (d['payMinLpa'] as num?)?.toDouble() ?? 0,
      payMaxLpa: (d['payMaxLpa'] as num?)?.toDouble() ?? 0,
      description: d['description'] as String? ?? '',
      skills: (d['skills'] as List?)?.cast<String>() ?? const [],
      wantedTraits: {
        for (final e in ((d['wantedTraits'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toDouble(),
      },
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      hidden: d['hidden'] == true,
    );
  }
}

/// What a recruiter sees about a student who chose to be visible, at
/// `candidates/{uid}`. Written by the student's own app.
class CandidateCard {
  const CandidateCard({
    required this.uid,
    required this.fullName,
    required this.college,
    required this.degree,
    required this.branch,
    required this.graduationYear,
    required this.city,
    required this.skills,
    required this.traits,
    required this.matchProfile,
    this.targetRole = '',
    this.links = const [],
    this.projectTitles = const [],
    this.updatedAt,
  });

  final String uid;
  final String fullName;
  final String college;
  final String degree;
  final String branch;
  final String graduationYear;
  final String city;
  final List<String> skills;

  /// Work-style quiz results, trait id → 0..100.
  final Map<String, double> traits;

  /// The profile in the backend's matching format (`ProfileIn`).
  final Map<String, dynamic> matchProfile;
  final String targetRole;
  final List<String> links;
  final List<String> projectTitles;
  final DateTime? updatedAt;

  String get headline => [
        [degree, branch].where((s) => s.isNotEmpty).join(' '),
        college,
        if (graduationYear.isNotEmpty) "'${graduationYear.length == 4 ? graduationYear.substring(2) : graduationYear}",
      ].where((s) => s.isNotEmpty).join(' · ');

  static CandidateCard fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CandidateCard(
      uid: doc.id,
      fullName: d['fullName'] as String? ?? '',
      college: d['college'] as String? ?? '',
      degree: d['degree'] as String? ?? '',
      branch: d['branch'] as String? ?? '',
      graduationYear: d['graduationYear'] as String? ?? '',
      city: d['city'] as String? ?? '',
      skills: (d['skills'] as List?)?.cast<String>() ?? const [],
      traits: {
        for (final e in ((d['traits'] as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toDouble(),
      },
      matchProfile: Map<String, dynamic>.from(d['matchProfile'] as Map? ?? const {}),
      targetRole: d['targetRole'] as String? ?? '',
      links: (d['links'] as List?)?.cast<String>() ?? const [],
      projectTitles: (d['projectTitles'] as List?)?.cast<String>() ?? const [],
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
