import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/api_config.dart';
import '../../auth/application/auth_providers.dart';
import '../data/resume_api.dart';
import '../data/scan_history_repository.dart';
import '../domain/scan_report.dart';
import 'resume_import_controller.dart';

final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>(
  (ref) => ScanHistoryRepository(ref.watch(firestoreProvider)),
);

/// The signed-in user's past scans, newest first.
final scanHistoryProvider = StreamProvider<List<ScanRecord>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(scanHistoryRepositoryProvider).watch(user.uid);
});

/// One saved scan, by id.
final scanRecordProvider =
    StreamProvider.family<ScanRecord?, String>((ref, scanId) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(scanHistoryRepositoryProvider).watchOne(user.uid, scanId);
});

enum ScanPhase { idle, scanning, done }

class ResumeScanState {
  const ResumeScanState({
    this.phase = ScanPhase.idle,
    this.fileName,
    this.report,
    this.error,
    this.savedToHistory = false,
  });

  final ScanPhase phase;
  final String? fileName;
  final ScanReport? report;
  final String? error;

  /// False if the report couldn't be saved (e.g. offline) — still shown.
  final bool savedToHistory;
}

final resumeScanControllerProvider =
    NotifierProvider.autoDispose<ResumeScanController, ResumeScanState>(
        ResumeScanController.new);

/// Pick → scan → show report → save to history.
class ResumeScanController extends Notifier<ResumeScanState> {
  @override
  ResumeScanState build() => const ResumeScanState();

  Future<void> pickAndScan() async {
    final picked = await ref.read(resumeFilePickerProvider).pick();
    if (picked == null) return; // cancelled
    if (picked.bytes.length > ApiConfig.maxUploadBytes) {
      state = const ResumeScanState(error: 'Please choose a file under 5 MB.');
      return;
    }
    state = ResumeScanState(phase: ScanPhase.scanning, fileName: picked.name);
    try {
      final report = await ref
          .read(resumeApiProvider)
          .scan(bytes: picked.bytes, fileName: picked.name);
      if (!ref.mounted) return;
      state = ResumeScanState(
          phase: ScanPhase.done, fileName: picked.name, report: report);
      await _saveToHistory(picked.name, report);
    } on ResumeApiException catch (e) {
      if (!ref.mounted) return;
      state = ResumeScanState(error: e.message);
    } catch (_) {
      if (!ref.mounted) return;
      state = const ResumeScanState(
          error: 'Something went wrong while scanning. Please try again.');
    }
  }

  Future<void> _saveToHistory(String fileName, ScanReport report) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(scanHistoryRepositoryProvider)
          .add(uid, fileName, report)
          .timeout(const Duration(seconds: 15));
      if (!ref.mounted) return;
      state = ResumeScanState(
        phase: ScanPhase.done,
        fileName: fileName,
        report: report,
        savedToHistory: true,
      );
    } catch (_) {
      // The report is still shown; it just isn't in history.
    }
  }

  void reset() => state = const ResumeScanState();
}
