import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/features/profile/domain/profile_data.dart';
import 'package:verixa/features/resume/domain/match_report.dart';

Map<String, dynamic> matchJson() => {
      'matchScore': 86,
      'skillCoverage': 57,
      'verdict': 'strong',
      'job': {
        'title': 'Software Engineer – Backend (Fresher)',
        'seniority': 'Entry level',
        'yearsRequired': 0,
        'education': 'B.Tech/B.E. in Computer Science',
      },
      'requirements': [
        {'text': 'Strong programming skills in Java or Python',
         'importance': 'required', 'kind': 'skill', 'status': 'met',
         'score': 1.0, 'evidence': 'Skills: Java, Python'},
        {'text': 'Exposure to Docker and Kubernetes', 'importance': 'preferred',
         'kind': 'skill', 'status': 'missing', 'score': 0.2, 'evidence': ''},
      ],
      'matchedSkills': ['Java', 'Python'],
      'missingSkills': [
        {'skill': 'Docker', 'importance': 'preferred'},
      ],
      'suggestions': ['Only add skills you genuinely have.'],
      'semantic': true,
    };

void main() {
  test('parses the match report', () {
    final r = MatchReport.fromJson(matchJson());
    expect(r.matchScore, 86);
    expect(r.verdict, MatchVerdict.strong);
    expect(r.jobTitle, startsWith('Software Engineer'));
    expect(r.yearsRequired, 0);
    expect(r.requirements.first.required, isTrue);
    expect(r.requirements.last.required, isFalse);
    expect(r.requirements.last.status, MatchStatus.missing);
    expect(r.missingSkills.single.required, isFalse);
  });

  test('history keeps a short JD snippet and reads back the same report', () {
    final r = MatchReport.fromJson(matchJson());
    final jd = 'Backend role. ' * 60; // ~840 chars
    final stored = MatchRecord.toFirestore(jd, r);
    expect((stored['jdSnippet'] as String).length, 300);
    final back = MatchReport.fromJson({...stored, 'createdAt': null});
    expect(back.matchScore, 86);
    expect(back.jobTitle, r.jobTitle);
    expect(back.requirements.first.evidence, 'Skills: Java, Python');
    expect(back.missingSkills.single.skill, 'Docker');
  });

  test('profile is sent in the backend’s ProfileIn shape', () {
    final profile = ProfileData.fromFirestore({
      'status': 'student',
      'fullName': 'Test',
      'organisation': 'JNTU',
      'statusDetails': {'degree': 'B.Tech', 'branch': 'CSE'},
      'careerGoal': {'targetRole': 'Backend Developer'},
      'skills': {'technical': ['Java'], 'tools': ['Git'], 'soft': ['Teamwork']},
      'projects': [
        {'title': 'Verixa', 'description': 'App', 'techStack': ['Flutter']},
      ],
      'experience': {
        'entries': [
          {'type': 'internship', 'company': 'Acme', 'role': 'Intern',
           'description': 'APIs'},
        ],
      },
      'extras': {'certifications': ['AWS CCP']},
    });
    final json = matchProfileJson(profile);
    expect(json['status'], 'student');
    expect(json['targetRole'], 'Backend Developer');
    expect(json['degree'], 'B.Tech');
    expect(json['skills'], ['Java']);
    expect(json['softSkills'], ['Teamwork']);
    expect((json['projects'] as List).single['techStack'], ['Flutter']);
    expect((json['experience'] as List).single['type'], 'internship');
    expect(json['certifications'], ['AWS CCP']);
    expect(json['totalExperienceYears'], isNull);
  });
}
