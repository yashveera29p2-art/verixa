import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/features/companies/data/company_repository.dart';
import 'package:verixa/features/companies/domain/company.dart';
import 'package:verixa/features/companies/domain/company_category.dart';

/// Checks the real seed file, so a broken edit to companies.json fails
/// here instead of on someone's phone.
void main() {
  late List<Company> companies;

  setUpAll(() {
    final raw = File(CompanyRepository.assetPath).readAsStringSync();
    companies = CompanyRepository.parseCompanies(raw);
  });

  test('has roughly 8–10 companies in every category (CLAUDE.md §4.1)', () {
    for (final category in CompanyCategory.values) {
      final count = companies.where((c) => c.category == category).length;
      expect(count, inInclusiveRange(8, 10), reason: category.title);
    }
  });

  test('ids are unique and URL-safe', () {
    final ids = companies.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9-]+$').hasMatch(id), isTrue, reason: id);
    }
  });

  test('every company has the content the detail screen needs', () {
    for (final c in companies) {
      final why = c.id;
      expect(c.name, isNotEmpty, reason: why);
      expect(c.sector, isNotEmpty, reason: why);
      expect(c.summary, isNotEmpty, reason: why);
      expect(c.expectations.skills, isNotEmpty, reason: why);
      expect(c.expectations.traits, isNotEmpty, reason: why);
      expect(c.expectations.academics, isNotEmpty, reason: why);
      expect(c.expectations.experience, isNotEmpty, reason: why);
      expect(c.resumePattern.length, isNotEmpty, reason: why);
      expect(c.resumePattern.sectionOrder.length, greaterThanOrEqualTo(4),
          reason: why);
      expect(c.resumePattern.emphasise, isNotEmpty, reason: why);
      expect(c.resumePattern.avoid, isNotEmpty, reason: why);
      expect(c.resumePattern.atsNotes, isNotEmpty, reason: why);
    }
  });

  test('every company has an https source and a review date', () {
    for (final c in companies) {
      expect(c.sources, isNotEmpty, reason: c.id);
      for (final url in c.sources) {
        expect(url.startsWith('https://'), isTrue, reason: '${c.id}: $url');
      }
      expect(c.lastReviewed.isAfter(DateTime(2026)), isTrue, reason: c.id);
    }
  });

  group('initials for the logo placeholder', () {
    Company named(String name) => Company.fromJson({
          'id': 'x',
          'name': name,
          'category': 'MNC',
          'lastReviewed': '2026-11-11',
        });

    test('uses first letters of the first two words', () {
      expect(named('Tata Consultancy Services').initials, 'TC');
      expect(named('Dream Sports').initials, 'DS');
    });

    test('uses two letters for one-word names', () {
      expect(named('Infosys').initials, 'IN');
    });

    test('skips "India" in names like "IBM India"', () {
      expect(named('IBM India').initials, 'IB');
      expect(named('Deloitte India').initials, 'DE');
    });
  });

  test('rejects an entry with an unknown category', () {
    expect(
      () => Company.fromJson({
        'id': 'x',
        'name': 'X',
        'category': 'Bank',
        'lastReviewed': '2026-11-11',
      }),
      throwsFormatException,
    );
  });

  test('logo domain comes from the careers URL', () {
    final companies = CompanyRepository.parseCompanies(
        File('assets/data/companies.json').readAsStringSync());
    String? domainOf(String id) =>
        companies.firstWhere((c) => c.id == id).logoDomain;
    expect(domainOf('tcs'), 'www.tcs.com');
    expect(domainOf('wipro'), 'wipro.com');
    expect(domainOf('cred'), 'cred.club');
  });
}
