import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/features/profile/domain/profile_data.dart';
import 'package:verixa/features/resume/data/resume_pdf.dart';
import 'package:verixa/features/resume/domain/resume_builder.dart';
import 'package:verixa/features/resume/domain/resume_version.dart';

/// Renders every template. Set `VERIXA_PDF_OUT=<dir>` to save the files for
/// a visual check.
void main() {
  final profile = ProfileData.fromFirestore({
    'status': 'student',
    'contact': {
      'fullName': 'Asha Rao',
      'city': 'Bengaluru',
      'state': 'Karnataka',
      'linkedin': 'linkedin.com/in/asharao',
      'github': 'github.com/asharao',
    },
    'statusDetails': {
      'college': 'RV College of Engineering',
      'degree': 'B.Tech',
      'branch': 'Computer Science',
      'graduationYear': '2027',
      'cgpa': '8.9',
    },
    'careerGoal': {'targetRole': 'Backend Developer'},
    'education': {
      'class12': {'board': 'CBSE', 'school': 'DPS Bangalore', 'score': '94%', 'year': '2023'},
      'class10': {'board': 'CBSE', 'school': 'DPS Bangalore', 'score': '96%', 'year': '2021'},
    },
    'experience': {
      'entries': [
        {
          'type': 'internship',
          'company': 'Acme Technologies',
          'role': 'Software Intern',
          'start': 'May 2025',
          'end': 'Jul 2025',
          'description': 'Built REST APIs in Spring Boot for the payments team.\n'
              'Wrote JUnit tests, raising coverage from 40% to 75%.\n'
              'Cut report generation time by 30% with query caching.',
        },
      ],
    },
    'projects': [
      {
        'title': 'Verixa',
        'description': 'Resume security scanner and builder app. Detects hidden '
            'text and prompt injection. Matches profiles to job descriptions.',
        'techStack': ['Flutter', 'FastAPI', 'spaCy'],
        'link': 'github.com/asharao/verixa',
        'duration': '2025',
      },
      {
        'title': 'Campus Events API',
        'description': 'REST API for college events with JWT auth and PostgreSQL.',
        'techStack': ['Java', 'Spring Boot', 'PostgreSQL'],
        'duration': '2024',
      },
    ],
    'skills': {
      'technical': ['Java', 'Python', 'Spring Boot', 'Flutter', 'SQL', 'REST APIs'],
      'tools': ['Git', 'Docker', 'Postman'],
      'soft': ['Teamwork', 'Communication'],
      'languages': ['English', 'Hindi', 'Kannada'],
    },
    'extras': {
      'certifications': ['AWS Cloud Practitioner (2025)', 'Oracle Java SE 17 (2024)'],
      'achievements': ['Smart India Hackathon 2024 – finalist', 'LeetCode 450+ problems'],
      'positions': ['Technical lead, Coding Club (2024–25)'],
    },
  });

  for (final t in ResumeTemplate.values) {
    test('renders the ${t.name} template', () async {
      final v = ResumeVersion(
        name: 'Sample',
        template: t,
        sectionOrder: defaultSectionOrder(profile.status),
        summary: defaultSummary(profile, focus: const ['Java', 'Spring Boot']),
        focusSkills: const ['Java', 'Spring Boot'],
      );
      final bytes = await ResumePdf.resume(
          buildResume(profile, v, phone: '+91 98765 43210', email: 'asha@example.com'),
          t);
      expect(bytes.length, greaterThan(1000));
      final out = Platform.environment['VERIXA_PDF_OUT'];
      if (out != null) File('$out/${t.name}.pdf').writeAsBytesSync(bytes);
    });
  }
}
