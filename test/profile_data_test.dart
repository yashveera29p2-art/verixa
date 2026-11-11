import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/app/routes.dart';
import 'package:verixa/features/auth/domain/user_profile.dart';
import 'package:verixa/features/profile/domain/profile_data.dart';
import 'package:verixa/features/profile/domain/profile_section.dart';

/// A freshly onboarded user: only the Phase 2 top-level fields.
Map<String, dynamic> onboarded({String status = 'student'}) => {
      'uid': 'u1',
      'phone': '+919999999999',
      'fullName': 'Test Student',
      'status': status,
      'organisation': 'JNTU Hyderabad',
    };

void main() {
  group('a newly onboarded profile', () {
    final p = ProfileData.fromFirestore(onboarded());

    test('starts at 0% with Contact as the next step', () {
      expect(p.completion, 0);
      expect(p.nextIncomplete, ProfileSection.contact);
    });

    test('prefills name and college from onboarding', () {
      expect(p.contact.fullName, 'Test Student');
      expect(p.statusDetails.college, 'JNTU Hyderabad');
    });

    test('Extras is optional and not counted', () {
      expect(ProfileSection.core, isNot(contains(ProfileSection.extras)));
      expect(ProfileSection.core.length, 7);
      expect(p.summaryFor(ProfileSection.extras), 'Optional');
    });
  });

  group('status branching (CLAUDE.md §5)', () {
    test('student needs course details incl. current year', () {
      const partial = StatusDetails(
        status: UserStatus.student,
        college: 'C', degree: 'B.Tech', branch: 'CSE',
        graduationYear: '2027', cgpa: '8.1',
      );
      expect(partial.isComplete, isFalse); // missing currentYear
      const full = StatusDetails(
        status: UserStatus.student,
        college: 'C', degree: 'B.Tech', branch: 'CSE',
        currentYear: '3rd year', graduationYear: '2027', cgpa: '8.1',
      );
      expect(full.isComplete, isTrue);
      expect(full.toMap().containsKey('company'), isFalse);
    });

    test('fresher also needs a target role', () {
      const d = StatusDetails(
        status: UserStatus.fresher,
        college: 'C', degree: 'B.Tech', branch: 'CSE',
        graduationYear: '2025', cgpa: '7.9',
      );
      expect(d.isComplete, isFalse);
      expect(d.toMap().containsKey('targetRole'), isTrue);
      expect(d.toMap().containsKey('currentYear'), isFalse);
    });

    test('working professional uses company as organisation', () {
      const d = StatusDetails(
        status: UserStatus.workingProfessional,
        company: 'Infosys', designation: 'SE',
        startDate: 'Jun 2023', totalExperienceYears: '2',
      );
      expect(d.isComplete, isTrue);
      expect(d.organisation, 'Infosys');
      expect(d.toMap().keys,
          unorderedEquals(['company', 'designation', 'startDate',
              'totalExperienceYears']));
    });
  });

  group('section completion', () {
    test('education needs 10th plus 12th or a diploma', () {
      const r = SchoolRecord(board: 'CBSE', school: 'S', score: '90', year: '2019');
      expect(const EducationHistory(class10: r).isComplete, isFalse);
      expect(const EducationHistory(class10: r, class12: r).isComplete, isTrue);
      expect(
        const EducationHistory(class10: r, additional: [
          HigherQualification(qualification: 'Diploma in ECE'),
        ]).isComplete,
        isTrue,
      );
    });

    test('"no experience yet" counts as done', () {
      expect(const ExperienceHistory().isComplete, isFalse);
      expect(const ExperienceHistory(noneYet: true).isComplete, isTrue);
    });

    test('noneYet is dropped once an entry exists', () {
      const h = ExperienceHistory(
        entries: [ExperienceEntry(company: 'X', role: 'Intern')],
        noneYet: true,
      );
      expect(h.toMap()['noneYet'], isFalse);
    });

    test('completion and next step move as sections are filled', () {
      final data = {
        ...onboarded(),
        'contact': {'fullName': 'Test Student', 'city': 'Hyderabad', 'state': 'Telangana'},
        'skills': {'technical': ['Java']},
        'projects': [
          {'title': 'Verixa'},
        ],
      };
      final p = ProfileData.fromFirestore(data);
      expect(p.completedCoreCount, 3);
      expect(p.completion, closeTo(3 / 7, 1e-9));
      expect(p.nextIncomplete, ProfileSection.status);
      expect(p.summaryFor(ProfileSection.projects), '1 project');
    });
  });

  test('every section has an editor route', () {
    for (final s in ProfileSection.values) {
      expect(ProfileSection.fromId(s.id), s);
      final path = AppRoutes.profileEdit(s.id);
      expect(AppRoutes.isProtected(path), isTrue);
    }
    expect(AppRoutes.profileEdit('skills', guided: true),
        '/profile/edit/skills?guided=1');
  });
}
