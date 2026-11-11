import '../../auth/domain/user_profile.dart';
import '../../profile/domain/profile_data.dart';
import 'resume_version.dart';

/// One entry in a resume section, e.g. a job or a project.
class ResumeItem {
  const ResumeItem({
    this.heading = '',
    this.subheading = '',
    this.meta = '',
    this.bullets = const [],
    this.line = '',
    this.bullet = false,
  });

  final String heading;
  final String subheading;

  /// Right-aligned detail, usually dates.
  final String meta;
  final List<String> bullets;

  /// A plain line of text (summary, skill rows, links).
  final String line;

  /// Show [line] as a bullet point (certifications, achievements…).
  final bool bullet;
}

class ResumeBlock {
  const ResumeBlock(this.kind, this.items);
  final ResumeSectionKind kind;
  final List<ResumeItem> items;
  String get title => kind.label;
}

/// Everything needed to render a resume, built only from profile data.
class ResumeContent {
  const ResumeContent({
    required this.name,
    required this.headline,
    required this.contact,
    required this.blocks,
  });

  final String name;
  final String headline;
  final List<String> contact;
  final List<ResumeBlock> blocks;

  Map<String, dynamic> toJson() => {
    'name': name,
    'headline': headline,
    'contact': contact,
    'blocks': [
      for (final b in blocks)
        {
          'title': b.title,
          'items': [
            for (final i in b.items)
              {
                'heading': i.heading,
                'subheading': i.subheading,
                'meta': i.meta,
                'bullets': i.bullets,
                'line': i.line,
                'bullet': i.bullet,
              },
          ],
        },
    ],
  };
}

bool _has(String s) => s.trim().isNotEmpty;
String _join(Iterable<String> parts, [String sep = ', ']) =>
    parts.where(_has).map((p) => p.trim()).join(sep);

/// Turns a free-text description into bullet points: one per line, or one
/// per sentence when it's a single paragraph.
List<String> toBullets(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'^\s*[-•*▪●◦]\s*'), '').trim())
      .where(_has)
      .toList();
  if (lines.length > 1) return lines;
  if (lines.isEmpty) return const [];
  return lines.first
      .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'))
      .map((s) => s.trim())
      .where(_has)
      .toList();
}

bool _sameSkill(String a, String b) {
  final x = a.toLowerCase().trim(), y = b.toLowerCase().trim();
  return x == y ||
      (x.length > 2 && y.contains(x)) ||
      (y.length > 2 && x.contains(y));
}

/// The profile's own skills (technical + tools).
List<String> profileSkills(ProfileData p) => [
  ...p.skills.technical,
  ...p.skills.tools,
];

/// Skills from [wanted] that the profile genuinely has, in the profile's
/// own wording.
List<String> focusSkillsFor(ProfileData p, List<String> wanted) => [
  for (final s in profileSkills(p))
    if (wanted.any((w) => _sameSkill(s, w))) s,
];

/// Share (0–100) of [wanted] skills the profile covers.
int? skillAlignment(ProfileData p, List<String> wanted) {
  if (wanted.isEmpty) return null;
  final have = profileSkills(p);
  final covered = wanted.where((w) => have.any((s) => _sameSkill(s, w))).length;
  return (100 * covered / wanted.length).round();
}

/// Default order of sections. Freshers and students lead with education;
/// professionals lead with experience. A company's recommended order
/// ([patternOrder], from companies.json) wins when given.
List<ResumeSectionKind> defaultSectionOrder(
  UserStatus status, {
  List<String> patternOrder = const [],
}) {
  final base = status == UserStatus.workingProfessional
      ? const [
          ResumeSectionKind.summary,
          ResumeSectionKind.experience,
          ResumeSectionKind.skills,
          ResumeSectionKind.projects,
          ResumeSectionKind.education,
          ResumeSectionKind.certifications,
          ResumeSectionKind.achievements,
          ResumeSectionKind.activities,
        ]
      : const [
          ResumeSectionKind.summary,
          ResumeSectionKind.education,
          ResumeSectionKind.skills,
          ResumeSectionKind.projects,
          ResumeSectionKind.experience,
          ResumeSectionKind.certifications,
          ResumeSectionKind.achievements,
          ResumeSectionKind.activities,
        ];
  final order = <ResumeSectionKind>[];
  for (final label in patternOrder) {
    final kind = _kindFor(label.toLowerCase());
    if (kind != null && !order.contains(kind)) order.add(kind);
  }
  return [...order, ...base.where((k) => !order.contains(k))];
}

ResumeSectionKind? _kindFor(String l) {
  if (l.contains('contact')) return null;
  if (l.contains('summary') || l.contains('objective')) {
    return ResumeSectionKind.summary;
  }
  if (l.contains('education')) return ResumeSectionKind.education;
  if (l.contains('project')) return ResumeSectionKind.projects;
  if (l.contains('experience') || l.contains('internship')) {
    return ResumeSectionKind.experience;
  }
  if (l.contains('skill')) return ResumeSectionKind.skills;
  if (l.contains('certification')) return ResumeSectionKind.certifications;
  if (l.contains('achievement') ||
      l.contains('contest') ||
      l.contains('award')) {
    return ResumeSectionKind.achievements;
  }
  if (l.contains('activit') ||
      l.contains('leadership') ||
      l.contains('extracurricular') ||
      l.contains('open source') ||
      l.contains('publication')) {
    return ResumeSectionKind.activities;
  }
  return null;
}

/// The role the user is aiming for, from Career goal or Status.
String targetRoleOf(ProfileData p) => _has(p.careerGoal.targetRole)
    ? p.careerGoal.targetRole.trim()
    : p.statusDetails.targetRole.trim();

/// A short summary written only from profile facts. The user can edit it.
String defaultSummary(ProfileData p, {List<String> focus = const []}) {
  if (_has(p.careerGoal.objective)) return p.careerGoal.objective.trim();
  final d = p.statusDetails;
  final skills = (focus.isNotEmpty ? focus : profileSkills(p)).take(4).toList();
  final role = targetRoleOf(p);
  final String who;
  if (p.status == UserStatus.workingProfessional) {
    who = _join([
      _has(d.designation) ? d.designation : 'Professional',
      if (_has(d.totalExperienceYears))
        'with ${d.totalExperienceYears} years of experience',
      if (_has(d.company)) 'at ${d.company}',
    ], ' ');
  } else {
    final degree = _join([d.degree, d.branch], ' ');
    who = _join([
      p.status == UserStatus.student
          ? '${_has(degree) ? degree : 'Engineering'} student'
          : '${_has(degree) ? degree : 'Engineering'} graduate',
      if (_has(d.college)) 'at ${d.college}',
    ], ' ');
  }
  final parts = [
    '$who.',
    if (skills.isNotEmpty) 'Skilled in ${_join(skills)}.',
    if (_has(role)) 'Looking for a $role role.',
  ];
  return parts.join(' ');
}

/// Builds the resume from the live profile and the version's choices.
ResumeContent buildResume(
  ProfileData p,
  ResumeVersion v, {
  String phone = '',
  String email = '',
}) {
  final c = p.contact;
  final contact = [
    phone,
    email,
    _join([c.city, c.state]),
    c.linkedin,
    c.github,
    c.portfolio,
  ].where(_has).map((s) => s.trim()).toList();

  final blocks = <ResumeBlock>[];
  for (final kind in v.visibleSections) {
    final items = _itemsFor(kind, p, v);
    if (items.isNotEmpty) blocks.add(ResumeBlock(kind, items));
  }
  final d = p.statusDetails;
  final headline =
      p.status == UserStatus.workingProfessional && _has(d.designation)
      ? d.designation.trim()
      : targetRoleOf(p);
  return ResumeContent(
    name: _has(c.fullName) ? c.fullName.trim() : 'Your name',
    headline: headline,
    contact: contact,
    blocks: blocks,
  );
}

List<ResumeItem> _itemsFor(
  ResumeSectionKind kind,
  ProfileData p,
  ResumeVersion v,
) {
  final d = p.statusDetails;
  final x = p.extras;
  switch (kind) {
    case ResumeSectionKind.summary:
      return _has(v.summary) ? [ResumeItem(line: v.summary.trim())] : const [];

    case ResumeSectionKind.education:
      final student = p.status == UserStatus.student;
      return [
        if (_has(d.degree) || _has(d.college))
          ResumeItem(
            heading: _join([d.degree, d.branch], ', '),
            subheading: d.college,
            meta: _has(d.graduationYear)
                ? (student ? 'Expected ${d.graduationYear}' : d.graduationYear)
                : '',
            line: _has(d.cgpa) ? 'CGPA: ${d.cgpa}' : '',
          ),
        for (final q in p.education.additional)
          if (_has(q.qualification))
            ResumeItem(
              heading: q.qualification,
              subheading: q.institution,
              meta: q.year,
              line: _has(q.score) ? 'Score: ${q.score}' : '',
            ),
        for (final (label, r) in [
          ('Class XII', p.education.class12),
          ('Class X', p.education.class10),
        ])
          if (_has(r.school))
            ResumeItem(
              heading: _join([label, r.board], ' — '),
              subheading: r.school,
              meta: r.year,
              line: _has(r.score) ? 'Score: ${r.score}' : '',
            ),
      ];

    case ResumeSectionKind.experience:
      final entries = p.experience.entries
          .where((e) => _has(e.company))
          .toList();
      final current =
          p.status == UserStatus.workingProfessional &&
              _has(d.company) &&
              !entries.any((e) => _sameSkill(e.company, d.company))
          ? [
              ResumeItem(
                heading: d.designation,
                subheading: d.company,
                meta: _join([d.startDate, 'Present'], ' – '),
              ),
            ]
          : const <ResumeItem>[];
      return [
        ...current,
        for (final e in entries)
          ResumeItem(
            heading: _join([
              e.role,
              if (e.type == 'internship' &&
                  !e.role.toLowerCase().contains('intern'))
                '(Internship)',
            ], ' '),
            subheading: e.company,
            meta: e.duration,
            bullets: toBullets(e.description),
          ),
      ];

    case ResumeSectionKind.projects:
      int score(ProjectEntry pr) => pr.techStack
          .where((t) => v.focusSkills.any((f) => _sameSkill(t, f)))
          .length;
      final projects = p.projects.where((pr) => _has(pr.title)).toList()
        ..sort((a, b) => score(b).compareTo(score(a)));
      return [
        for (final pr in projects)
          ResumeItem(
            heading: pr.title,
            subheading: _join(pr.techStack),
            meta: pr.duration,
            bullets: toBullets(pr.description),
            line: pr.link,
          ),
      ];

    case ResumeSectionKind.skills:
      final technical = [
        ...v.focusSkills.where(p.skills.technical.contains),
        ...p.skills.technical.where((s) => !v.focusSkills.contains(s)),
      ];
      final tools = [
        ...v.focusSkills.where(p.skills.tools.contains),
        ...p.skills.tools.where((s) => !v.focusSkills.contains(s)),
      ];
      return [
        for (final (label, list) in [
          ('Technical', technical),
          ('Tools', tools),
          ('Soft skills', p.skills.soft),
          ('Languages', p.skills.languages),
        ])
          if (list.isNotEmpty) ResumeItem(heading: label, line: _join(list)),
      ];

    case ResumeSectionKind.certifications:
      return [
        for (final s in x['certifications']) ResumeItem(line: s, bullet: true),
      ];

    case ResumeSectionKind.achievements:
      return [
        for (final s in [...x['achievements'], ...x['publications']])
          ResumeItem(line: s, bullet: true),
      ];

    case ResumeSectionKind.activities:
      return [
        for (final s in [
          ...x['positions'],
          ...x['clubs'],
          ...x['nssNcc'],
          ...x['volunteering'],
        ])
          ResumeItem(line: s, bullet: true),
      ];
  }
}

/// A plain, honest cover letter from profile facts. The user edits it
/// before sending; nothing is invented.
String writeCoverLetter(ProfileData p, ResumeVersion v) {
  final d = p.statusDetails;
  final name = _has(p.contact.fullName) ? p.contact.fullName.trim() : '';
  final role = _has(v.jobTitle) ? v.jobTitle : targetRoleOf(p);
  final company = v.targetKind == ResumeTargetKind.company
      ? v.targetLabel.replaceAll(RegExp(r'\s*\(.*\)$'), '')
      : '';
  final roleText = _has(role) ? 'the $role role' : 'a role in your team';
  final skills = (v.focusSkills.isNotEmpty ? v.focusSkills : profileSkills(p))
      .take(5)
      .toList();

  final intro = p.status == UserStatus.workingProfessional
      ? 'I am currently working as ${_has(d.designation) ? d.designation : 'a professional'}'
            '${_has(d.company) ? ' at ${d.company}' : ''}'
            '${_has(d.totalExperienceYears) ? ', with ${d.totalExperienceYears} years of experience' : ''}.'
      : 'I am ${p.status == UserStatus.student ? 'pursuing' : 'a graduate of'} '
            '${_join([d.degree, d.branch], ' ').isEmpty ? 'my degree' : _join([d.degree, d.branch], ' ')}'
            '${_has(d.college) ? ' at ${d.college}' : ''}'
            '${_has(d.cgpa) ? ' with a CGPA of ${d.cgpa}' : ''}.';

  final paragraphs = <String>[
    'Dear Hiring Manager,',
    'I am writing to apply for $roleText${_has(company) ? ' at $company' : ''}. $intro',
  ];

  final exp = p.experience.entries.where((e) => _has(e.company)).toList();
  if (exp.isNotEmpty) {
    final e = exp.first;
    final what = toBullets(e.description).take(2).join(' ');
    paragraphs.add(
      'As ${_has(e.role) ? e.role : 'part of the team'} at ${e.company}'
              '${_has(e.duration) ? ' (${e.duration})' : ''}, I gained hands-on experience. '
              '$what'
          .trim(),
    );
  }

  int score(ProjectEntry pr) =>
      pr.techStack.where((t) => skills.any((f) => _sameSkill(t, f))).length;
  final projects = p.projects.where((pr) => _has(pr.title)).toList()
    ..sort((a, b) => score(b).compareTo(score(a)));
  if (projects.isNotEmpty) {
    final pr = projects.first;
    final first = toBullets(pr.description).firstOrNull ?? '';
    paragraphs.add(
      'One project I am proud of is ${pr.title}'
              '${pr.techStack.isNotEmpty ? ', built with ${_join(pr.techStack.take(4))}' : ''}. '
              '$first'
          .trim(),
    );
  }

  if (skills.isNotEmpty) {
    paragraphs.add(
      'My skills in ${_join(skills)} match what this role needs, and '
      'I am keen to keep learning and contribute from day one.',
    );
  }
  paragraphs.add(
    'Thank you for considering my application. I would welcome the '
    'chance to discuss how I can contribute${_has(company) ? ' to $company' : ''}.',
  );
  paragraphs.add('Sincerely,\n${_has(name) ? name : '[Your name]'}');
  return paragraphs.join('\n\n');
}
