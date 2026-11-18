import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../jobs/application/jobs_controller.dart' show jobsApiProvider;
import '../../jobs/domain/job_models.dart';
import '../domain/recruiter_models.dart';
import 'recruiter_providers.dart';

class TalentState {
  const TalentState({
    this.loading = false,
    this.error,
    this.candidates = const [],
    this.fits = const {},
    this.rankedFor = '',
  });

  final bool loading;
  final String? error;
  final List<CandidateCard> candidates;

  /// Fit by candidate uid (empty until ranked).
  final Map<String, JobFit> fits;

  /// Title of the job the list is ranked for.
  final String rankedFor;

  List<CandidateCard> get sorted => [...candidates]
    ..sort((a, b) => (fits[b.uid]?.score ?? -1).compareTo(fits[a.uid]?.score ?? -1));
}

final talentControllerProvider =
    NotifierProvider<TalentController, TalentState>(TalentController.new);

/// Loads students who opted in and ranks them for a job with matching v2
/// (skills shown in projects and internships, plus work-style fit).
class TalentController extends Notifier<TalentState> {
  @override
  TalentState build() => const TalentState();

  Future<void> load() async {
    state = TalentState(loading: true, fits: state.fits, rankedFor: state.rankedFor);
    try {
      final list = await ref.read(recruiterRepositoryProvider).fetchCandidates();
      if (!ref.mounted) return;
      state = TalentState(candidates: list);
    } catch (_) {
      if (!ref.mounted) return;
      state = const TalentState(error: 'Couldn’t load candidates. Check your connection.');
    }
  }

  Future<void> rank({
    required String title,
    required String description,
    required Map<String, double> wantedTraits,
  }) async {
    if (state.candidates.isEmpty) await load();
    final candidates = state.candidates;
    if (candidates.isEmpty) return;
    state = TalentState(loading: true, candidates: candidates);
    try {
      final fits = await ref.read(jobsApiProvider).rankCandidates(
            title: title,
            description: description,
            wantedTraits: wantedTraits,
            candidates: [for (final c in candidates) (c.uid, c.matchProfile, c.traits)],
          );
      if (!ref.mounted) return;
      state = TalentState(candidates: candidates, fits: fits, rankedFor: title);
    } catch (e) {
      if (!ref.mounted) return;
      state = TalentState(candidates: candidates, error: e.toString());
    }
  }
}
