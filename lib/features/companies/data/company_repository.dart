import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/company.dart';
import '../domain/company_category.dart';

/// Loads company guidance from the bundled seed file.
///
/// Phase 4 reads `assets/data/companies.json`; a later phase can swap this
/// for a Firestore-backed version without changing the screens.
class CompanyRepository {
  CompanyRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/data/companies.json';

  final AssetBundle _bundle;
  List<Company>? _cache;

  Future<List<Company>> fetchAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(assetPath);
    return _cache = parseCompanies(raw);
  }

  Future<List<Company>> fetchByCategory(CompanyCategory category) async {
    final all = await fetchAll();
    return all.where((c) => c.category == category).toList();
  }

  Future<Company?> fetchById(String id) async {
    final all = await fetchAll();
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Parses the seed file's JSON text. Public so tests can check the file.
  static List<Company> parseCompanies(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['companies'] as List<dynamic>;
    return list
        .map((e) => Company.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
