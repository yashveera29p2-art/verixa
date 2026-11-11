import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_config.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile_section.dart';
import '../data/resume_api.dart';
import '../data/resume_file_picker.dart';
import '../domain/parsed_resume.dart';
import '../domain/profile_import.dart';

final resumeApiProvider = Provider<ResumeApi>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return ResumeApi(
    baseUrl: ApiConfig.baseUrl,
    idToken: () async => auth.currentUser?.getIdToken(),
  );
});

final resumeFilePickerProvider = Provider<ResumeFilePicker>(
  (ref) => const ResumeFilePicker(),
);

enum ImportPhase { idle, uploading, review, importing, done }

class ResumeImportState {
  const ResumeImportState({
    this.phase = ImportPhase.idle,
    this.fileName,
    this.result,
    this.selected = const {},
    this.error,
  });

  final ImportPhase phase;
  final String? fileName;
  final ParsedResume? result;

  /// Sections the user has ticked for import.
  final Set<ProfileSection> selected;
  final String? error;

  ResumeImportState copyWith({
    ImportPhase? phase,
    String? fileName,
    ParsedResume? result,
    Set<ProfileSection>? selected,
    String? error,
    bool clearError = false,
  }) => ResumeImportState(
    phase: phase ?? this.phase,
    fileName: fileName ?? this.fileName,
    result: result ?? this.result,
    selected: selected ?? this.selected,
    error: clearError ? null : (error ?? this.error),
  );
}

final resumeImportControllerProvider =
    NotifierProvider.autoDispose<ResumeImportController, ResumeImportState>(
      ResumeImportController.new,
    );

/// Pick → upload → review → import.
class ResumeImportController extends Notifier<ResumeImportState> {
  @override
  ResumeImportState build() => const ResumeImportState();

  Future<void> pickAndParse() async {
    final picked = await ref.read(resumeFilePickerProvider).pick();
    if (picked == null) return; // cancelled
    if (picked.bytes.length > ApiConfig.maxUploadBytes) {
      state = state.copyWith(error: 'Please choose a file under 5 MB.');
      return;
    }
    state = ResumeImportState(
      phase: ImportPhase.uploading,
      fileName: picked.name,
    );
    try {
      final result = await ref
          .read(resumeApiProvider)
          .parse(bytes: picked.bytes, fileName: picked.name);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: ImportPhase.review,
        result: result,
        selected: result.availableSections.toSet(),
      );
    } on ResumeApiException catch (e) {
      if (!ref.mounted) return;
      state = ResumeImportState(error: e.message);
    } catch (_) {
      // Anything unexpected must never leave the screen stuck on "Reading…".
      if (!ref.mounted) return;
      state = const ResumeImportState(
        error:
            'Something went wrong while reading your resume. Please try again.',
      );
    }
  }

  /// Starts reviewing a result that was already fetched (e.g. by a scan).
  void loadResult(ParsedResume result, String fileName) {
    state = ResumeImportState(
      phase: ImportPhase.review,
      fileName: fileName,
      result: result,
      selected: result.availableSections.toSet(),
    );
  }

  void toggle(ProfileSection section) {
    final next = {...state.selected};
    if (!next.remove(section)) next.add(section);
    state = state.copyWith(selected: next);
  }

  /// Merges the ticked sections into the profile. Returns true on success.
  Future<bool> importSelected() async {
    final result = state.result;
    if (result == null) return false;
    state = state.copyWith(phase: ImportPhase.importing, clearError: true);
    final current = await loadCurrentProfile(ref);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (!ref.mounted) return false;
    if (current == null || uid == null) {
      // Never fail silently: tell the user why nothing happened.
      state = state.copyWith(
        phase: ImportPhase.review,
        error:
            'Couldn’t load your profile to merge into. '
            'Check your connection and try again.',
      );
      return false;
    }

    final plan = ProfileImport.plan(current, result, state.selected);
    try {
      await ref
          .read(profileRepositoryProvider)
          .saveSections(
            uid,
            contact: plan.contact,
            status: plan.status,
            education: plan.education,
            careerGoal: plan.careerGoal,
            experience: plan.experience,
            projects: plan.projects,
            skills: plan.skills,
            extras: plan.extras,
          );
      if (!ref.mounted) return false;
      state = state.copyWith(phase: ImportPhase.done);
      return true;
    } catch (_) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        phase: ImportPhase.review,
        error: 'Couldn’t save to your profile. Check your connection.',
      );
      return false;
    }
  }

  void reset() => state = const ResumeImportState();
}
