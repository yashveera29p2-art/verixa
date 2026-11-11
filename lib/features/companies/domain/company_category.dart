import 'package:flutter/material.dart';

/// The three company types on Home (CLAUDE.md §4).
enum CompanyCategory {
  mnc(
    id: 'mnc',
    title: 'MNC',
    description: 'Large global firms with structured, high-volume hiring.',
    icon: Icons.apartment_outlined, // building
  ),
  sme(
    id: 'sme',
    title: 'SME',
    description: 'Growing mid-size companies that value hands-on versatility.',
    icon: Icons.work_outline, // briefcase
  ),
  startup(
    id: 'startup',
    title: 'Startup',
    description: 'Fast-moving teams looking for ownership and shipped work.',
    icon: Icons.rocket_launch_outlined, // rocket
  );

  const CompanyCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  /// Used in routes (`/companies/mnc`) and, later, in companies.json.
  final String id;
  final String title;
  final String description;
  final IconData icon;

  static CompanyCategory? fromId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}
