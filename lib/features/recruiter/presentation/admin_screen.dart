import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../reviews/reviews.dart';
import '../application/recruiter_providers.dart';
import '../domain/recruiter_models.dart';

final _requestsProvider = StreamProvider<List<RecruiterAccount>>(
    (ref) => ref.watch(recruiterRepositoryProvider).watchRequests());
final _reviewsProvider = StreamProvider<List<CompanyReview>>(
    (ref) => ref.watch(reviewsRepositoryProvider).watchRecent());
final _jobsProvider = StreamProvider<List<PostedJob>>(
    (ref) => ref.watch(recruiterRepositoryProvider).watchAllJobs());

/// Verixa team only: approve recruiters, hide reviews and job posts.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Admin', style: AppTypography.headlineMedium),
          bottom: const TabBar(
            labelColor: AppColors.botanicalGreen,
            indicatorColor: AppColors.botanicalGreen,
            tabs: [Tab(text: 'Recruiters'), Tab(text: 'Reviews'), Tab(text: 'Jobs')],
          ),
        ),
        body: const TabBarView(children: [_Recruiters(), _Reviews(), _Jobs()]),
      ),
    );
  }
}

class _Recruiters extends ConsumerWidget {
  const _Recruiters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_requestsProvider);
    final repo = ref.read(recruiterRepositoryProvider);
    return list.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Couldn’t load: $e')),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No recruiter requests yet.'))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                for (final r in items)
                  Card(
                    color: AppColors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r.fullName} · ${r.status.label}', style: AppTypography.labelLarge),
                          Text('${r.designation}, ${r.company}', style: AppTypography.bodyMedium),
                          Text('${r.workEmail} · ${r.phone}', style: AppTypography.bodySmall),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (r.status != RecruiterStatus.rejected)
                                TextButton(
                                  onPressed: () => repo.setStatus(r.uid, RecruiterStatus.rejected),
                                  child: const Text('Reject'),
                                ),
                              if (r.status != RecruiterStatus.approved)
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.botanicalGreen),
                                  onPressed: () => repo.setStatus(r.uid, RecruiterStatus.approved),
                                  child: const Text('Approve'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_reviewsProvider).value ?? const <CompanyReview>[];
    final repo = ref.read(reviewsRepositoryProvider);
    if (list.isEmpty) return const Center(child: Text('No reviews yet.'));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final r in list)
          ListTile(
            title: Text('${r.companyId} · ${r.overall}★ · ${r.author}'),
            subtitle: Text(r.text.isEmpty ? '(no comment)' : r.text),
            trailing: TextButton(
              onPressed: () => repo.setHidden(r.id, !r.hidden),
              child: Text(r.hidden ? 'Show' : 'Hide'),
            ),
          ),
      ],
    );
  }
}

class _Jobs extends ConsumerWidget {
  const _Jobs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(_jobsProvider).value ?? const <PostedJob>[];
    final repo = ref.read(recruiterRepositoryProvider);
    if (list.isEmpty) return const Center(child: Text('No posted jobs yet.'));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final j in list)
          ListTile(
            title: Text('${j.title} · ${j.company}'),
            subtitle: Text(j.hidden ? 'Hidden' : 'Visible to students'),
            trailing: TextButton(
              onPressed: () => repo.setJobHidden(j.id, !j.hidden),
              child: Text(j.hidden ? 'Show' : 'Hide'),
            ),
          ),
      ],
    );
  }
}
