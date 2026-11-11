import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/phone_utils.dart';
import '../../auth/application/auth_providers.dart';
import '../../companies/domain/company.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile_data.dart';
import '../data/resume_api.dart';
import '../data/resume_pdf.dart';
import '../data/resume_repository.dart';
import '../domain/match_report.dart';
import '../domain/resume_builder.dart';
import '../domain/resume_version.dart';
import 'resume_import_controller.dart';

final resumeRepositoryProvider = Provider<ResumeRepository>(
  (ref) => ResumeRepository(ref.watch(firestoreProvider)),
);

/// Saved resume versions, most recently edited first.
final resumeVersionsProvider = StreamProvider<List<ResumeVersion>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(resumeRepositoryProvider).watchAll(user.uid);
});

final resumeVersionProvider = StreamProvider.family<ResumeVersion?, String>((
  ref,
  id,
) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  return ref.watch(resumeRepositoryProvider).watchOne(user.uid, id);
});

/// Resume content for [v], rebuilt whenever the profile changes (in build).
AsyncValue<ResumeContent> watchResumeContent(WidgetRef ref, ResumeVersion v) =>
    _content(ref.watch(currentUserProvider), ref.watch(profileDataProvider), v);

/// Same as [watchResumeContent], for event handlers. Null while loading.
ResumeContent? readResumeContent(WidgetRef ref, ResumeVersion v) => _content(
  ref.read(currentUserProvider),
  ref.read(profileDataProvider),
  v,
).value;

AsyncValue<ResumeContent> _content(
  User? user,
  AsyncValue<ProfileData?> profile,
  ResumeVersion v,
) {
  final phone = user?.phoneNumber;
  return profile.whenData(
    (p) => buildResume(
      p ?? _emptyProfile,
      v,
      phone: phone == null ? '' : PhoneUtils.pretty(phone),
      email: user?.email ?? '',
    ),
  );
}

final _emptyProfile = ProfileData.fromFirestore(const {});

/// What the user picked on the "New resume" screen.
class NewResumeRequest {
  const NewResumeRequest({
    required this.name,
    required this.targetKind,
    required this.template,
    this.company,
    this.jobDescription = '',
  });

  final String name;
  final ResumeTargetKind targetKind;
  final ResumeTemplate template;
  final Company? company;
  final String jobDescription;
}

final newResumeControllerProvider =
    NotifierProvider.autoDispose<NewResumeController, AsyncValue<String?>>(
      NewResumeController.new,
    );

/// Creates a tailored resume version (feature 9). Returns its id.
class NewResumeController extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  Future<String?> create(NewResumeRequest r) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) {
      state = AsyncError('Please sign in again.', StackTrace.current);
      return null;
    }
    if (r.targetKind == ResumeTargetKind.job &&
        r.jobDescription.trim().length < 50) {
      state = AsyncError(
        'Paste the full job description — a few lines at least.',
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncLoading();
    final profile = await loadCurrentProfile(ref);
    if (!ref.mounted) return null;
    if (profile == null) {
      state = AsyncError(
        'Couldn’t load your profile. Check your connection.',
        StackTrace.current,
      );
      return null;
    }

    try {
      var focus = <String>[];
      int? alignment;
      var jobTitle = '';
      var label = '';
      var patternOrder = const <String>[];

      switch (r.targetKind) {
        case ResumeTargetKind.general:
          break;
        case ResumeTargetKind.company:
          final c = r.company!;
          label = '${c.name} (${c.category.title})';
          focus = focusSkillsFor(profile, c.expectations.skills);
          alignment = skillAlignment(profile, c.expectations.skills);
          patternOrder = c.resumePattern.sectionOrder;
        case ResumeTargetKind.job:
          final MatchReport report = await ref
              .read(resumeApiProvider)
              .matchJob(
                jobDescription: r.jobDescription.trim(),
                profile: matchProfileJson(profile),
              );
          if (!ref.mounted) return null;
          focus = focusSkillsFor(profile, report.matchedSkills);
          alignment = report.matchScore;
          jobTitle = report.jobTitle;
          label = report.jobTitle.isNotEmpty
              ? report.jobTitle
              : 'Job description';
      }

      final version = ResumeVersion(
        name: r.name.trim().isNotEmpty
            ? r.name.trim()
            : (label.isNotEmpty ? label : 'My resume'),
        targetKind: r.targetKind,
        targetLabel: label,
        companyId: r.company?.id ?? '',
        jobTitle: jobTitle,
        template: r.template,
        sectionOrder: defaultSectionOrder(
          profile.status,
          patternOrder: patternOrder,
        ),
        summary: defaultSummary(profile, focus: focus),
        focusSkills: focus,
        alignmentScore: alignment,
      );
      final id = ref.read(resumeRepositoryProvider).create(uid, version);
      state = AsyncData(id);
      return id;
    } on ResumeApiException catch (e) {
      if (ref.mounted) state = AsyncError(e.message, StackTrace.current);
    } catch (_) {
      if (ref.mounted) {
        state = AsyncError(
          'Something went wrong. Please try again.',
          StackTrace.current,
        );
      }
    }
    return null;
  }
}

final resumeExporterProvider = Provider<ResumeExporter>(
  (ref) => ResumeExporter(ref.watch(resumeApiProvider)),
);

/// Saves edits and exports resumes / cover letters (feature 10).
class ResumeExporter {
  ResumeExporter(this._api);

  final ResumeApi _api;

  static String fileBase(ResumeContent c, ResumeVersion v) {
    String slug(String s) => s
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return [slug(c.name), slug(v.name)].where((s) => s.isNotEmpty).join('_');
  }

  Future<Uint8List> pdf(ResumeContent c, ResumeVersion v) =>
      ResumePdf.resume(c, v.template);

  Future<void> shareDocx(ResumeContent c, ResumeVersion v) async {
    final bytes = await _api.resumeDocx({
      ...c.toJson(),
      'template': v.template.name,
    });
    await _share(bytes, '${fileBase(c, v)}.docx', _docxMime);
  }

  Future<Uint8List> coverLetterPdf(String text, ResumeContent c) =>
      ResumePdf.coverLetter(text, c);

  Future<void> shareCoverLetterDocx(
    String text,
    ResumeContent c,
    ResumeVersion v,
  ) async {
    final bytes = await _api.coverLetterDocx(
      name: c.name,
      contact: c.contact,
      text: text,
    );
    await _share(bytes, '${fileBase(c, v)}_Cover_Letter.docx', _docxMime);
  }

  static const _docxMime =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  Future<void> _share(Uint8List bytes, String name, String mime) =>
      SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: mime)],
          fileNameOverrides: [name],
        ),
      );
}

/// Saves a version after edits in the editor.
Future<void> saveResumeVersion(WidgetRef ref, ResumeVersion v) async {
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) return;
  await ref.read(resumeRepositoryProvider).save(uid, v);
}

Future<void> deleteResumeVersion(WidgetRef ref, String id) async {
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) return;
  await ref.read(resumeRepositoryProvider).delete(uid, id);
}
