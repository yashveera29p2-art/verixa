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

  // Jobs tab
  static final jobsSearch = GlobalKey(debugLabel: 'tour-jobs-search');
  static final jobsFilters = GlobalKey(debugLabel: 'tour-jobs-filters');
  static final jobsList = GlobalKey(debugLabel: 'tour-jobs-list');
  // Prep tab
  static final prepSearch = GlobalKey(debugLabel: 'tour-prep-search');
  static final prepFirst = GlobalKey(debugLabel: 'tour-prep-first');
  // Profile tab
  static final profileAbout = GlobalKey(debugLabel: 'tour-profile-about');
  static final profileProgress = GlobalKey(debugLabel: 'tour-profile-progress');
  static final profileRecruiters = GlobalKey(debugLabel: 'tour-profile-recruiters');
  // Centre menu and its pages
  static final menuCreate = GlobalKey(debugLabel: 'tour-menu-create');
  static final menuScan = GlobalKey(debugLabel: 'tour-menu-scan');
  static final menuMatch = GlobalKey(debugLabel: 'tour-menu-match');
  static final resumesNew = GlobalKey(debugLabel: 'tour-resumes-new');
  static final scanChoose = GlobalKey(debugLabel: 'tour-scan-choose');
  static final scanHistory = GlobalKey(debugLabel: 'tour-scan-history');
  static final matchBox = GlobalKey(debugLabel: 'tour-match-box');
  static final matchButton = GlobalKey(debugLabel: 'tour-match-button');
  // Recruiter pages
  static final talentHeader = GlobalKey(debugLabel: 'tour-talent-header');
  static final postForm = GlobalKey(debugLabel: 'tour-post-form');
  static final postButton2 = GlobalKey(debugLabel: 'tour-post-submit');

  static List<TourStep> get jobs => [
        TourStep(
          target: jobsFilters,
          title: 'Filter what matters to you',
          body: 'High package, low layoffs, good work-life balance, pay '
              'level or unpaid, internships or full-time. Tap to combine.',
        ),
        TourStep(
          target: jobsList,
          title: 'Ranked for you',
          body: 'Each job shows a match % and why it fits. Open one to see '
              'gaps, company reviews and the apply link.',
        ),
      ];

  static List<TourStep> get prep => [
        TourStep(
          target: prepFirst,
          title: 'Prepare for a company',
          body: 'Search or pick a company to see its hiring rounds, topics, '
              'common questions and the skills you’re still missing.',
        ),
      ];

  static List<TourStep> get profile => [
        TourStep(
          target: profileProgress,
          title: 'Complete your profile',
          body: 'Fill the sections step by step. Everything else in Verixa '
              '(resumes, matching, jobs) is built from these details.',
        ),
        TourStep(
          target: profileRecruiters,
          title: 'Let recruiters find you',
          body: 'Take the 2-minute work-style quiz, then switch on “Visible '
              'to recruiters” if you want approved recruiters to see you.',
        ),
      ];

  static List<TourStep> get menu => [
        TourStep(
          target: menuCreate,
          title: 'Create resume',
          body: 'Build a resume from your profile, tailored to a company, a '
              'job description or in general. Export as PDF or Word.',
        ),
        TourStep(
          target: menuScan,
          title: 'Upload & scan',
          body: 'Check any resume for hidden text, prompt injection and '
              'keyword stuffing, and get an estimated ATS score.',
        ),
        TourStep(
          target: menuMatch,
          title: 'Match a job',
          body: 'Paste a job description to see how well your profile fits '
              'and what’s missing.',
        ),
      ];

  static List<TourStep> get resumes => [
        TourStep(
          target: resumesNew,
          title: 'Start a new resume',
          body: 'Pick what to tailor it for and a template. Your saved '
              'versions appear in this list.',
        ),
      ];

  static List<TourStep> get scan => [
        TourStep(
          target: scanChoose,
          title: 'Choose a resume file',
          body: 'Pick a PDF or Word file. It’s checked on our server and not '
              'stored.',
        ),
      ];

  static List<TourStep> get match => [
        TourStep(
          target: matchBox,
          title: 'Paste the job description',
          body: 'Copy the whole posting: job title, responsibilities, '
              'required and preferred skills, experience and education.',
        ),
      ];

  static List<TourStep> get talent => [
        TourStep(
          target: talentHeader,
          title: 'Rank candidates',
          body: 'Choose one of your jobs (or type the skills you need), pick '
              'the work style you value, then tap Rank candidates.',
        ),
      ];

  static List<TourStep> get post => [
        TourStep(
          target: postForm,
          title: 'Describe the role',
          body: 'Title, type, location and pay (or unpaid). Key skills and a '
              'clear description help students and the ranking.',
        ),
      ];

  static List<TourStep> get student => [
        TourStep(
          target: companyTypes,
          title: 'Company types',
          body: 'Open MNC, SME or Startup to see what those companies '
              'expect, their pay and job security, and the resume shape '
              'that suits them.',
        ),
        TourStep(
          target: resumeButton,
          title: 'Resume tools',
          body: 'Create a tailored resume, upload and scan one for hidden '
              'tricks and ATS score, or match it against a job description.',
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
      ];
}
