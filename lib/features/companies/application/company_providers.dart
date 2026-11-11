import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/company_repository.dart';
import '../domain/company.dart';
import '../domain/company_category.dart';

final companyRepositoryProvider =
    Provider<CompanyRepository>((ref) => CompanyRepository());

/// Companies in one category, in the order they appear in the seed file.
final companiesByCategoryProvider =
    FutureProvider.family<List<Company>, CompanyCategory>((ref, category) {
  return ref.watch(companyRepositoryProvider).fetchByCategory(category);
});

/// One company by id, or null if it doesn't exist.
final companyByIdProvider =
    FutureProvider.family<Company?, String>((ref, id) {
  return ref.watch(companyRepositoryProvider).fetchById(id);
});
