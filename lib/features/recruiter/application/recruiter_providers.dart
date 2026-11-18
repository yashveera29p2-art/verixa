import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../legal/consent_repository.dart';
import '../data/recruiter_repository.dart';
import '../domain/recruiter_models.dart';

final recruiterRepositoryProvider = Provider<RecruiterRepository>(
  (ref) => RecruiterRepository(ref.watch(firestoreProvider)),
);

final consentRepositoryProvider = Provider<ConsentRepository>(
  (ref) => ConsentRepository(ref.watch(firestoreProvider)),
);

/// The signed-in recruiter's account (null while loading or if none).
final myRecruiterAccountProvider = StreamProvider<RecruiterAccount?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(recruiterRepositoryProvider).watchAccount(uid);
});

final myPostedJobsProvider = StreamProvider<List<PostedJob>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(recruiterRepositoryProvider).watchMyJobs(uid);
});

final shortlistIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const {});
  return ref.watch(recruiterRepositoryProvider).watchShortlistIds(uid);
});

final shortlistProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(recruiterRepositoryProvider).watchShortlist(uid);
});
