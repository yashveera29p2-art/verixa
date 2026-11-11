import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../data/match_history_repository.dart';
import '../data/resume_api.dart';
import '../domain/match_report.dart';
import 'resume_import_controller.dart';

final matchHistoryRepositoryProvider = Provider<MatchHistoryRepository>(
  (ref) => MatchHistoryRepository(ref.watch(firestoreProvider)),
);

final matchHistoryProvider = StreamProvider<List<MatchRecord>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(matchHistoryRepositoryProvider).watch(user.uid);
});

final matchRecordProvider = StreamProvider.family<MatchRecord?, String>((
  ref,
  id,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(matchHistoryRepositoryProvider).watchOne(user.uid, id);
});

class JdMatchState {
  const JdMatchState({
    this.matching = false,
    this.report,
    this.error,
    this.savedToHistory = false,
  });

  final bool matching;
  final MatchReport? report;
  final String? error;
  final bool savedToHistory;
}

final jdMatchControllerProvider =
    NotifierProvider.autoDispose<JdMatchController, JdMatchState>(
      JdMatchController.new,
    );

/// Paste JD → match against the profile → save to history (feature 8).
class JdMatchController extends Notifier<JdMatchState> {
  static const minLength = 50;

  @override
  JdMatchState build() => const JdMatchState();

  Future<void> match(String jobDescription) async {
    final jd = jobDescription.trim();
    if (jd.length < minLength) {
      state = const JdMatchState(
        error: 'Paste the full job description — a few lines at least.',
      );
      return;
    }
    state = const JdMatchState(matching: true);
    final profile = await loadCurrentProfile(ref);
    if (!ref.mounted) return;
    if (profile == null) {
      state = const JdMatchState(
        error: 'Couldn’t load your profile. Check your connection.',
      );
      return;
    }
    try {
      final report = await ref
          .read(resumeApiProvider)
          .matchJob(jobDescription: jd, profile: matchProfileJson(profile));
      if (!ref.mounted) return;
      state = JdMatchState(report: report);
      await _save(jd, report);
    } on ResumeApiException catch (e) {
      if (!ref.mounted) return;
      state = JdMatchState(error: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = const JdMatchState(
        error: 'Something went wrong while matching. Please try again.',
      );
    }
  }

  Future<void> _save(String jd, MatchReport report) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(matchHistoryRepositoryProvider)
          .add(uid, jd, report)
          .timeout(const Duration(seconds: 15));
      if (ref.mounted) {
        state = JdMatchState(report: report, savedToHistory: true);
      }
    } catch (_) {
      // Report still shown; just not saved.
    }
  }

  void reset() => state = const JdMatchState();
}
