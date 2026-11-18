import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../companies/application/company_providers.dart';
import '../../companies/domain/company.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile_data.dart';
import '../../recruiter/application/recruiter_providers.dart';
import '../../resume/domain/match_report.dart' show matchProfileJson;
import '../data/jobs_api.dart';
import '../domain/job_models.dart';

final jobsApiProvider = Provider<JobsApi>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return JobsApi(
    baseUrl: ApiConfig.baseUrl,
    idToken: () async => auth.currentUser?.getIdToken(),
  );
});

class JobsState {
  const JobsState({
    this.query = '',
    this.filters = const {},
    this.loading = false,
    this.error,
    this.source = '',
    this.jobs = const [],
    this.ranked = false,
  });

  final String query;
  final Set<JobFilter> filters;
  final bool loading;
  final String? error;

  /// "adzuna" or "sample".
  final String source;
  final List<RankedJob> jobs;

  /// False if ranking failed and jobs are shown unranked.
  final bool ranked;

  List<RankedJob> get visible =>
      jobs.where((j) => filters.every((f) => f.test(j))).toList();

  JobsState copyWith({
    String? query,
    Set<JobFilter>? filters,
    bool? loading,
    String? error,
    bool clearError = false,
    String? source,
    List<RankedJob>? jobs,
    bool? ranked,
  }) =>
      JobsState(
        query: query ?? this.query,
        filters: filters ?? this.filters,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
        source: source ?? this.source,
        jobs: jobs ?? this.jobs,
        ranked: ranked ?? this.ranked,
      );
}

final jobsControllerProvider =
    NotifierProvider<JobsController, JobsState>(JobsController.new);

/// Loads listings (Adzuna or samples + jobs posted on Verixa), ranks them
/// for the student with matching v2, and attaches company insights.
class JobsController extends Notifier<JobsState> {
  bool _started = false;

  @override
  JobsState build() => const JobsState();

  /// First open of the Jobs tab: search for the student's target role.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final profile = await loadCurrentProfile(ref);
    await search(_defaultQuery(profile));
  }

  String _defaultQuery(ProfileData? p) {
    if (p == null) return 'software developer';
    final role = p.careerGoal.targetRole.isNotEmpty
        ? p.careerGoal.targetRole
        : p.statusDetails.targetRole;
    if (role.trim().isNotEmpty) return role.trim();
    final skills = p.skills.technical.take(2).join(' ');
    return skills.isNotEmpty ? skills : 'software developer';
  }

  void toggleFilter(JobFilter f) {
    final next = {...state.filters};
    next.contains(f) ? next.remove(f) : next.add(f);
    // "Internships" and "Full-time" exclude each other.
    if (f == JobFilter.internship) next.remove(JobFilter.fullTime);
    if (f == JobFilter.fullTime) next.remove(JobFilter.internship);
    state = state.copyWith(filters: next);
  }

  Future<void> search(String query) async {
    state = state.copyWith(query: query, loading: true, clearError: true);
    try {
      final api = ref.read(jobsApiProvider);
      final internshipOnly = state.filters.contains(JobFilter.internship);
      final results = await Future.wait([
        api.search(query: query, internship: internshipOnly),
        ref.read(recruiterRepositoryProvider).fetchOpenJobs().catchError((_) => <Never>[]),
        ref.read(allCompaniesProvider.future),
        loadCurrentProfile(ref),
      ]);
      final (source, listed) = results[0] as (String, List<JobListing>);
      final posted = [
        for (final p in results[1] as List) JobListing.fromPosted(p),
      ];
      final companies = results[2] as List<Company>;
      final profile = results[3] as ProfileData?;
      final all = [...posted, ...listed];

      Map<String, JobFit> fits = const {};
      var ranked = false;
      if (profile != null && all.isNotEmpty) {
        try {
          fits = await api.rankJobs(profile: matchProfileJson(profile), jobs: all);
          ranked = true;
        } catch (_) {
          // Show the listings unranked rather than nothing.
        }
      }
      final jobs = [
        for (final j in all)
          RankedJob(job: j, fit: fits[j.id], company: matchCompany(j.company, companies)),
      ]..sort((a, b) => (b.fit?.score ?? -1).compareTo(a.fit?.score ?? -1));
      if (!ref.mounted) return;
      state = state.copyWith(
          loading: false, source: source, jobs: jobs, ranked: ranked);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

/// Finds which of Verixa's researched companies a listing's company name
/// refers to ("Infosys Limited" → Infosys), or null.
Company? matchCompany(String name, List<Company> companies) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'\b(india|ltd|limited|pvt|private|technologies|'
          r'systems|software|services|solutions|inc|llp|the)\b'), '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  final n = norm(name);
  if (n.length < 3) return null;
  for (final c in companies) {
    final cn = norm(c.name);
    final id = c.id.replaceAll('-', '');
    if (cn.isEmpty) continue;
    if (n == cn || n.startsWith(cn) || cn.startsWith(n) || n == id || n.startsWith(id)) {
      return c;
    }
  }
  return null;
}
