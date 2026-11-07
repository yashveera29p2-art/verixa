import 'package:cloud_firestore/cloud_firestore.dart';

/// The user's career status, chosen during onboarding.
enum UserStatus {
  student('student', 'Student'),
  fresher('fresher', 'Fresher'),
  workingProfessional('working_professional', 'Working professional');

  const UserStatus(this.id, this.label);

  /// Value stored in Firestore.
  final String id;

  /// Text shown in the UI.
  final String label;

  /// Students and freshers name a college; professionals name a company.
  bool get asksForCompany => this == UserStatus.workingProfessional;

  static UserStatus? fromId(String? id) {
    for (final status in values) {
      if (status.id == id) return status;
    }
    return null;
  }
}

/// The profile stored at `users/{uid}` in Firestore.
///
/// Phase 2 only collects the basics. More fields (CLAUDE.md §5) are added
/// step by step from the Profile screen later.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.phone,
    required this.fullName,
    required this.status,
    required this.organisation,
  });

  final String uid;
  final String phone;
  final String fullName;
  final UserStatus status;

  /// College (student / fresher) or company (working professional).
  final String organisation;

  String get firstName => fullName.trim().split(RegExp(r'\s+')).first;

  /// True once the short onboarding has been filled in.
  bool get isOnboardingComplete =>
      fullName.trim().isNotEmpty && organisation.trim().isNotEmpty;

  static UserProfile? fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final status = UserStatus.fromId(data['status'] as String?);
    if (status == null) return null;
    return UserProfile(
      uid: doc.id,
      phone: data['phone'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      status: status,
      organisation: data['organisation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'phone': phone,
        'fullName': fullName.trim(),
        'status': status.id,
        'organisation': organisation.trim(),
      };
}
