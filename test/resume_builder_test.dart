import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/features/auth/domain/user_profile.dart';
import 'package:verixa/features/profile/domain/profile_data.dart';
import 'package:verixa/features/resume/domain/resume_builder.dart';
import 'package:verixa/features/resume/domain/resume_version.dart';

ProfileData _profile() => ProfileData.fromFirestore({
      'status': 'student',
      'contact': {'fullName': 'Asha Rao', 'city': 'Bengaluru', 'state': 'Karnataka'},
      'statusDetails': {
        'college': 'RV College',
        'degree': 'B.Tech',
        'branch': 'CSE',
        'graduationYear': '2027',
        'cgpa': '8.9',
      },
      'projects': [
        {'title': 'Notes app', 'description': 'A notes app.', 'techStack': ['Flutter']},
        {
          'title': 'Payments API',
          'description': 'Built REST APIs. Added unit tests.',
          'techStack': ['Spring Boot', 'Java'],
        },
      ],
      'skills': {'technical': ['Flutter', 'Java', 'Spring Boot'], 'tools': ['Git']},
      'extras': {'certifications': ['AWS Cloud Practitioner']},
    });

void main() {
  test('company section order comes from its resume pattern', () {
    final order = defaultSectionOrder(UserStatus.student, patternOrder: [
      'Contact details',
      'Experience / internships',
      'Projects',
      'Skills',
      'Education',
    ]);
    expect(order.take(4), [
      ResumeSectionKind.experience,
      ResumeSectionKind.projects,
      ResumeSectionKind.skills,
      ResumeSectionKind.education,
    ]);
    expect(order.toSet().length, ResumeSectionKind.values.length);
  });

  test('focus skills and alignment only use skills the profile has', () {
    final p = _profile();
    expect(focusSkillsFor(p, ['Java', 'Kubernetes', 'spring boot']),
        ['Java', 'Spring Boot']);
    expect(skillAlignment(p, ['Java', 'Kubernetes']), 50);
  });

  test('resume content comes only from the profile, ordered by focus', () {
    final p = _profile();
    final v = ResumeVersion(
      name: 'Backend',
      sectionOrder: defaultSectionOrder(p.status),
      hiddenSections: {ResumeSectionKind.achievements},
      summary: defaultSummary(p, focus: ['Java']),
      focusSkills: const ['Java', 'Spring Boot'],
    );
    final c = buildResume(p, v, phone: '+91 98765 43210');

    expect(c.name, 'Asha Rao');
    expect(c.contact, contains('Bengaluru, Karnataka'));
    final titles = c.blocks.map((b) => b.kind).toList();
    // Experience is empty, so it's left out; hidden sections too.
    expect(titles, isNot(contains(ResumeSectionKind.experience)));
    expect(titles, isNot(contains(ResumeSectionKind.achievements)));

    final projects = c.blocks.firstWhere((b) => b.kind == ResumeSectionKind.projects);
    expect(projects.items.first.heading, 'Payments API'); // matches focus
    expect(projects.items.first.bullets, ['Built REST APIs.', 'Added unit tests.']);

    final skills = c.blocks.firstWhere((b) => b.kind == ResumeSectionKind.skills);
    expect(skills.items.first.line, 'Java, Spring Boot, Flutter');

    final education = c.blocks.firstWhere((b) => b.kind == ResumeSectionKind.education);
    expect(education.items.first.meta, 'Expected 2027');
    expect(c.blocks.first.items.first.line, contains('B.Tech CSE student at RV College'));
  });

  test('cover letter uses real facts and names the company', () {
    final p = _profile();
    final v = ResumeVersion(
      name: 'Infosys',
      targetKind: ResumeTargetKind.company,
      targetLabel: 'Infosys (MNC)',
      sectionOrder: ResumeSectionKind.values,
      focusSkills: const ['Java'],
    );
    final letter = writeCoverLetter(p, v);
    expect(letter, contains('at Infosys.'));
    expect(letter, contains('Payments API'));
    expect(letter, contains('CGPA of 8.9'));
    expect(letter, endsWith('Asha Rao'));
  });

  test('toBullets splits lines or sentences', () {
    expect(toBullets('- One\n- Two'), ['One', 'Two']);
    expect(toBullets('Did A. Did B.'), ['Did A.', 'Did B.']);
    expect(toBullets(''), isEmpty);
  });
}
