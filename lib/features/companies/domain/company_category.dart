import 'package:flutter/material.dart';

/// The three company types on Home (CLAUDE.md §4).
enum CompanyCategory {
  mnc(
    id: 'mnc',
    title: 'MNC',
    fullName: 'Multinational Corporation',
    description: 'Large global companies with structured, high-volume campus hiring.',
    icon: Icons.apartment_outlined, // building
  ),
  sme(
    id: 'sme',
    title: 'SME',
    fullName: 'Small & Medium Enterprise',
    description: 'Growing mid-size companies where you handle varied, hands-on work.',
    icon: Icons.work_outline, // briefcase
  ),
  startup(
    id: 'startup',
    title: 'Startup',
    description: 'Young, fast-moving teams that value ownership and shipped work.',
    icon: Icons.rocket_launch_outlined, // rocket
  );

  const CompanyCategory({
    required this.id,
    required this.title,
    this.fullName,
    required this.description,
    required this.icon,
  });

  /// Used in routes (`/companies/mnc`) and, later, in companies.json.
  final String id;
  final String title;

  /// e.g. "Multinational Corporation" (none for Startup).
  final String? fullName;
  final String description;
  final IconData icon;

  static CompanyCategory? fromId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Parses the `category` field in companies.json ("MNC", "SME", "Startup").
  static CompanyCategory? fromLabel(String? label) {
    for (final c in values) {
      if (c.title == label) return c;
    }
    return null;
  }
}
