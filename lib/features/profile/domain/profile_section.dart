import 'package:flutter/material.dart';

/// The step-by-step profile sections from CLAUDE.md §5, in order.
enum ProfileSection {
  contact(
    id: 'contact',
    title: 'Account & contact',
    description: 'Name, location and professional links',
    icon: Icons.person_outline,
  ),
  status(
    id: 'status',
    title: 'Current status',
    description: 'Your course or current job',
    icon: Icons.badge_outlined,
  ),
  education(
    id: 'education',
    title: 'Education history',
    description: '10th, 12th, diploma or postgraduate',
    icon: Icons.school_outlined,
  ),
  careerGoal(
    id: 'career-goal',
    title: 'Career goal',
    description: 'Target role and a short objective',
    icon: Icons.flag_outlined,
  ),
  experience(
    id: 'experience',
    title: 'Experience',
    description: 'Internships and jobs',
    icon: Icons.work_history_outlined,
  ),
  projects(
    id: 'projects',
    title: 'Projects',
    description: 'What you built and with what',
    icon: Icons.code,
  ),
  skills(
    id: 'skills',
    title: 'Skills',
    description: 'Technical, tools, soft skills, languages',
    icon: Icons.psychology_outlined,
  ),
  extras(
    id: 'extras',
    title: 'Extras',
    description: 'Certifications, achievements, activities',
    icon: Icons.emoji_events_outlined,
    isOptional: true,
  );

  const ProfileSection({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isOptional = false,
  });

  /// Used in routes: /profile/edit/career-goal
  final String id;
  final String title;
  final String description;
  final IconData icon;

  /// Optional sections don't count towards the completion percentage.
  final bool isOptional;

  static List<ProfileSection> get core =>
      values.where((s) => !s.isOptional).toList();

  static ProfileSection? fromId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}
