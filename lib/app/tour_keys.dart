import 'package:flutter/widgets.dart';

import '../core/widgets/guided_tour.dart';

/// Anchors the guided tour points at. Each key is attached to exactly one
/// widget (the nav items, the Home company types, the recruiter tabs).
abstract final class TourKeys {
  // Student
  static final companyTypes = GlobalKey(debugLabel: 'tour-company-types');
  static final homeTab = GlobalKey(debugLabel: 'tour-home');
  static final jobsTab = GlobalKey(debugLabel: 'tour-jobs');
  static final resumeButton = GlobalKey(debugLabel: 'tour-resume');
  static final prepTab = GlobalKey(debugLabel: 'tour-prep');
  static final profileTab = GlobalKey(debugLabel: 'tour-profile');

  // Recruiter
  static final talentTab = GlobalKey(debugLabel: 'tour-talent');
  static final postButton = GlobalKey(debugLabel: 'tour-post');
  static final myJobsTab = GlobalKey(debugLabel: 'tour-my-jobs');

  static List<TourStep> get student => [
        TourStep(
          target: companyTypes,
          title: 'Company types',
          body: 'Open MNC, SME or Startup to see what those companies '
              'expect, their pay and job security, and the resume shape '
              'that suits them.',
        ),
        TourStep(
          target: jobsTab,
          title: 'Jobs picked for you',
          body: 'Real job listings ranked by how well your profile fits, '
              'with filters for high package, low layoffs, work-life '
              'balance and paid or unpaid roles.',
        ),
        TourStep(
          target: resumeButton,
          title: 'Resume tools',
          body: 'Create a tailored resume, upload and scan one for hidden '
              'tricks and ATS score, or match it against a job description.',
        ),
        TourStep(
          target: prepTab,
          title: 'Placement prep',
          body: 'Interview rounds, topics and common questions for each '
              'company, plus a checklist built from your own skill gaps.',
        ),
        TourStep(
          target: profileTab,
          title: 'Your profile',
          body: 'Fill your details step by step, take the 2-minute '
              'work-style quiz, and choose whether recruiters can find '
              'you. About and the Terms are here too.',
        ),
      ];

  static List<TourStep> get recruiter => [
        TourStep(
          target: talentTab,
          title: 'Find talent',
          body: 'Students who chose to be visible, ranked against your job '
              'by skills they’ve proven in projects and internships, and '
              'by the work style you want.',
        ),
        TourStep(
          target: postButton,
          title: 'Post a job',
          body: 'Describe the role, pay and skills. It appears in students’ '
              'Jobs tab, and you can rank candidates against it.',
        ),
        TourStep(
          target: myJobsTab,
          title: 'Your jobs and shortlist',
          body: 'Manage the jobs you posted and the candidates you starred.',
        ),
      ];
}
