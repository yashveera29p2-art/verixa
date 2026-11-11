import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/features/auth/domain/user_profile.dart';
import 'package:verixa/features/profile/domain/profile_data.dart';
import 'package:verixa/features/profile/domain/profile_section.dart';
import 'package:verixa/features/resume/domain/parsed_resume.dart';
import 'package:verixa/features/resume/domain/profile_import.dart';

/// Shape of the backend's /v1/resumes/parse response.
Map<String, dynamic> backendJson() => {
      'contact': {
        'fullName': 'Priya Sharma',
        'email': 'priya@example.com',
        'phone': '+919876543210',
        'city': 'Hyderabad',
        'linkedin': 'linkedin.com/in/priya',
        'github': 'github.com/priya',
        'portfolio': '',
      },
      'careerGoal': {'objective': 'Aspiring backend engineer.'},
      'education': {
        'class10': {'board': 'CBSE', 'school': 'KV', 'score': '92%', 'year': '2020'},
        'class12': {'board': '', 'school': 'Narayana', 'score': '94%', 'year': '2022'},
        'degree': {
          'college': 'JNTU', 'degree': 'B.Tech', 'branch': 'CSE',
          'cgpa': '8.4', 'graduationYear': '2026',
        },
        'additional': [],
      },
      'experience': [
        {'type': 'internship', 'company': 'Acme', 'role': 'Intern',
         'start': 'May 2024', 'end': 'Jul 2024', 'description': 'APIs'},
      ],
      'projects': [
        {'title': 'Verixa', 'description': 'App', 'techStack': ['Flutter'],
         'link': '', 'duration': ''},
      ],
      'skills': {'technical': ['Java', 'SQL'], 'tools': ['Git'], 'soft': [],
                 'languages': ['English']},
      'extras': {'certifications': ['AWS CCP'], 'achievements': [],
                 'positions': [], 'hobbies': ['Chess']},
      'confidence': {'contact': 0.98, 'education': 1.0},
      'warnings': ['Check your dates.'],
      'meta': {'fileType': 'pdf', 'pages': 1, 'lines': 40,
               'sectionsFound': ['education', 'skills']},
    };

ProfileData existingProfile() => ProfileData.fromFirestore({
      'uid': 'u1',
      'phone': '+919999999999',
      'fullName': 'Priya S',
      'status': 'student',
      'organisation': 'JNTU',
      'contact': {'fullName': 'Priya S', 'city': '', 'linkedin': 'my-own-link'},
      'skills': {'technical': ['java', 'Dart']},
      'projects': [
        {'title': 'verixa', 'description': 'my version'},
      ],
    });

void main() {
  final parsed = ParsedResume.fromJson(backendJson());

  test('maps the backend response onto profile classes', () {
    expect(parsed.contact.fullName, 'Priya Sharma');
    expect(parsed.email, 'priya@example.com');
    expect(parsed.degree.branch, 'CSE');
    expect(parsed.education.class12.score, '94%');
    expect(parsed.experience.single.company, 'Acme');
    expect(parsed.projects.single.techStack, ['Flutter']);
    expect(parsed.extras['certifications'], ['AWS CCP']);
    expect(parsed.extras['hobbies'], ['Chess']);
    expect(parsed.warnings, ['Check your dates.']);
    expect(parsed.confidence['contact'], 0.98);
    expect(parsed.availableSections, ProfileSection.values);
  });

  test('empty response offers nothing to import', () {
    final empty = ParsedResume.fromJson(const {});
    expect(empty.availableSections, isEmpty);
  });

  group('import never overwrites what the user typed', () {
    final current = existingProfile();

    test('contact fills only empty fields', () {
      final c = ProfileImport.contact(current.contact, parsed.contact);
      expect(c.fullName, 'Priya S'); // kept
      expect(c.linkedin, 'my-own-link'); // kept
      expect(c.city, 'Hyderabad'); // filled
      expect(c.github, 'github.com/priya'); // filled
    });

    test('skills are merged without case-insensitive duplicates', () {
      final s = ProfileImport.skills(current.skills, parsed.skills);
      expect(s.technical, ['java', 'Dart', 'SQL']);
      expect(s.tools, ['Git']);
    });

    test('projects with the same title are not duplicated', () {
      final p = ProfileImport.projects(current.projects, parsed.projects);
      expect(p.length, 1);
      expect(p.single.description, 'my version');
    });

    test('status details fill course fields for students', () {
      final s = ProfileImport.status(current.statusDetails, parsed.degree);
      expect(s.college, 'JNTU'); // from onboarding, kept
      expect(s.branch, 'CSE');
      expect(s.cgpa, '8.4');
    });

    test('working professionals keep their job details untouched', () {
      const job = StatusDetails(
          status: UserStatus.workingProfessional, company: 'Infosys');
      expect(ProfileImport.status(job, parsed.degree), same(job));
    });

    test('experience added clears "no experience yet"', () {
      final e = ProfileImport.experience(
          const ExperienceHistory(noneYet: true), parsed.experience);
      expect(e.entries.length, 1);
      expect(e.noneYet, isFalse);
    });
  });

  test('plan only includes ticked sections', () {
    final plan = ProfileImport.plan(existingProfile(), parsed,
        {ProfileSection.skills, ProfileSection.education});
    expect(plan.skills, isNotNull);
    expect(plan.education!.class10.board, 'CBSE');
    expect(plan.contact, isNull);
    expect(plan.projects, isNull);
  });
}
