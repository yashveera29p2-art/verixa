import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/links.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_providers.dart';
import '../../reviews/reviews.dart';
import '../domain/job_models.dart';
import 'jobs_screen.dart' show MatchBadge;

/// One job: why it fits (or doesn't), the company's pay / layoffs /
/// work-life and reviews, prep, and Apply.
class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({super.key, required this.ranked});

  final RankedJob ranked;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _interested = false;
  bool _sending = false;

  Future<void> _expressInterest() async {
    final job = widget.ranked.job.posted;
    final user = ref.read(currentUserProvider);
    if (job == null || user == null) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('jobs')
          .doc(job.id)
          .collection('interested')
          .doc(user.uid)
          .set({'at': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _interested = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t send. Check your connection.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ranked;
    final j = r.job;
    final fit = r.fit;
    final company = r.company;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter, 0, AppSpacing.pageGutter, AppSpacing.md),
        child: j.source == JobSource.verixa
            ? AppButton(
                label: _interested ? 'Interest sent ✓' : 'I’m interested',
                isLoading: _sending,
                onPressed: _interested ? null : _expressInterest,
              )
            : AppButton(
                label: j.url.isEmpty ? 'Sample listing (no link)' : 'Apply on the company’s site',
                onPressed: j.url.isEmpty ? null : () => openLink(j.url),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter, 0, AppSpacing.pageGutter, AppSpacing.xl),
        children: staggered([
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.title, style: AppTypography.headlineLarge),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      [j.company, if (j.location.isNotEmpty) j.location].join(' · '),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              if (fit != null) MatchBadge(score: fit.score, size: 62),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${j.payText} · ${j.isInternship ? 'Internship' : 'Full-time'} · ${j.source.label}',
            style: AppTypography.labelMedium.copyWith(color: AppColors.botanicalGreen),
          ),
          if (fit != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _FitCard(fit: fit),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('About the role', style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(j.description.isEmpty ? 'No description provided.' : j.description,
              style: AppTypography.bodyMedium.copyWith(height: 1.5)),
          if (j.source == JobSource.adzuna) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Listing summary from Adzuna; the full posting is on the apply page.',
                style: AppTypography.bodySmall),
          ],
          if (company != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(child: Text('About ${company.name}', style: AppTypography.titleLarge)),
                TextButton(
                  onPressed: () => context.push(AppRoutes.prepFor(company.id)),
                  child: const Text('Prepare →'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            CompanyReviewsSection(company: company),
          ],
        ]),
      ),
    );
  }
}

class _FitCard extends StatelessWidget {
  const _FitCard({required this.fit});

  final JobFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.botanicalGreen.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why this match', style: AppTypography.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          if (fit.reasons.isEmpty)
            Text('Nothing in your profile clearly matches yet.',
                style: AppTypography.bodySmall),
          for (final reason in fit.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('✓ $reason', style: AppTypography.bodyMedium),
            ),
          if (fit.gaps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Missing: ${fit.gaps.join(', ')}',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text('An estimate from your profile, not a prediction of selection.',
              style: AppTypography.bodySmall.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}
