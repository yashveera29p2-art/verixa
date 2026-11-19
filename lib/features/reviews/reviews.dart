import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/utils/admin.dart';
import '../../core/widgets/app_button.dart';
import '../auth/application/auth_providers.dart';
import '../companies/domain/company.dart';
import '../profile/application/profile_providers.dart';
import '../jobs/application/jobs_controller.dart' show jobsApiProvider;
import '../resume/domain/writing_report.dart' show ReviewAnalysis;

/// One user review of a company, at `reviews/{companyId}_{uid}` (one per
/// person per company; writing again updates it).
class CompanyReview {
  const CompanyReview({
    required this.id,
    required this.companyId,
    required this.uid,
    required this.author,
    required this.overall,
    required this.workLife,
    required this.pay,
    required this.security,
    required this.text,
    required this.workedThere,
    this.createdAt,
    this.hidden = false,
  });

  final String id;
  final String companyId;
  final String uid;

  /// "Intern", "Employee" or "Student", never a name.
  final String author;
  final int overall, workLife, pay, security; // 1..5
  final String text;

  /// Self-reported: this company is in the reviewer's experience.
  final bool workedThere;
  final DateTime? createdAt;
  final bool hidden;

  static CompanyReview fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    int n(String k) => ((d[k] as num?)?.toInt() ?? 3).clamp(1, 5);
    return CompanyReview(
      id: doc.id,
      companyId: d['companyId'] as String? ?? '',
      uid: d['uid'] as String? ?? '',
      author: d['author'] as String? ?? 'Student',
      overall: n('overall'),
      workLife: n('workLife'),
      pay: n('pay'),
      security: n('security'),
      text: d['text'] as String? ?? '',
      workedThere: d['workedThere'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      hidden: d['hidden'] == true,
    );
  }
}

class ReviewsRepository {
  ReviewsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('reviews');

  Stream<List<CompanyReview>> watch(String companyId) => _col
      .where('companyId', isEqualTo: companyId)
      .where('hidden', isEqualTo: false)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(CompanyReview.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  Future<void> save({
    required String uid,
    required Company company,
    required String author,
    required bool workedThere,
    required int overall,
    required int workLife,
    required int pay,
    required int security,
    required String text,
  }) =>
      _col.doc('${company.id}_$uid').set({
        'companyId': company.id,
        'companyName': company.name,
        'uid': uid,
        'author': author,
        'workedThere': workedThere,
        'overall': overall,
        'workLife': workLife,
        'pay': pay,
        'security': security,
        'text': text.trim(),
        'hidden': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));

  Future<void> setHidden(String id, bool hidden) =>
      _col.doc(id).update({'hidden': hidden});

  /// Latest reviews across companies (admin moderation).
  Stream<List<CompanyReview>> watchRecent() => _col
      .orderBy('createdAt', descending: true)
      .limit(60)
      .snapshots()
      .map((s) => s.docs.map(CompanyReview.fromDoc).toList());
}

final reviewsRepositoryProvider =
    Provider<ReviewsRepository>((ref) => ReviewsRepository(ref.watch(firestoreProvider)));

final companyReviewsProvider =
    StreamProvider.family<List<CompanyReview>, String>(
        (ref, companyId) => ref.watch(reviewsRepositoryProvider).watch(companyId));

/// NLP sentiment and aspects of a company's reviews (null until there are
/// reviews or if the server can't be reached).
final reviewAnalysisProvider =
    FutureProvider.family<ReviewAnalysis?, String>((ref, companyId) async {
  final reviews = ref.watch(companyReviewsProvider(companyId)).value ?? const [];
  if (reviews.isEmpty) return null;
  try {
    return await ref.read(jobsApiProvider).analyzeReviews(
          [for (final r in reviews) r.text],
          [for (final r in reviews) r.overall],
        );
  } catch (_) {
    return null;
  }
});

/// Pay, job security and work-life summary (curated) plus user reviews,
/// with "Write a review".
class CompanyReviewsSection extends ConsumerWidget {
  const CompanyReviewsSection({super.key, required this.company});

  final Company company;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(companyReviewsProvider(company.id));
    final list = reviews.value ?? const <CompanyReview>[];
    final admin = isAdmin(ref.watch(currentUserProvider));
    double avg(int Function(CompanyReview) f) =>
        list.isEmpty ? 0 : list.map(f).reduce((a, b) => a + b) / list.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsightsCard(insights: company.insights),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                list.isEmpty ? 'No reviews yet' : 'Reviews (${list.length})',
                style: AppTypography.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => showWriteReview(context, company),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const Text('Write a review'),
              style: TextButton.styleFrom(foregroundColor: AppColors.botanicalGreen),
            ),
          ],
        ),
        if (list.isNotEmpty) ...[
          _SentimentCard(companyId: company.id),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xxs,
            children: [
              _AvgChip('Overall', avg((r) => r.overall)),
              _AvgChip('Work-life', avg((r) => r.workLife)),
              _AvgChip('Pay', avg((r) => r.pay)),
              _AvgChip('Job security', avg((r) => r.security)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final r in list.take(10))
            _ReviewTile(review: r, admin: admin),
        ] else
          Text(
            'Interned or worked here? Your review helps other students.',
            style: AppTypography.bodySmall,
          ),
      ],
    );
  }
}

/// The curated pay band, layoff risk and work-life summary.
class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key, required this.insights});

  final CompanyInsights insights;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.botanicalGreen),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 112,
                child: Text(label, style: AppTypography.bodySmall),
              ),
              Expanded(
                child: Text(value,
                    style: AppTypography.labelLarge.copyWith(fontSize: 14)),
              ),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.payments_outlined, 'Fresher pay',
              insights.payBand.isEmpty ? 'Not known' : insights.payBand),
          row(Icons.shield_outlined, 'Layoff risk', insights.layoffRisk.label),
          row(Icons.spa_outlined, 'Work-life', insights.workLife.label),
          Text(
            'Indicative, from public information; may be outdated.',
            style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _AvgChip extends StatelessWidget {
  const _AvgChip(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 18, color: AppColors.botanicalGreen),
          Text(' ${value.toStringAsFixed(1)} ',
              style: AppTypography.labelLarge.copyWith(fontSize: 14)),
          Text(label, style: AppTypography.bodySmall),
        ],
      );
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.review, required this.admin});

  final CompanyReview review;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.overall ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: AppColors.botanicalGreen,
                ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  review.workedThere ? '${review.author} · worked here' : review.author,
                  style: AppTypography.bodySmall,
                ),
              ),
              if (admin)
                TextButton(
                  onPressed: () =>
                      ref.read(reviewsRepositoryProvider).setHidden(review.id, true),
                  child: const Text('Hide'),
                ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(review.text, style: AppTypography.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet: four star ratings and a short comment.
Future<void> showWriteReview(BuildContext context, Company company) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _WriteReviewSheet(company: company),
    );

class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.company});

  final Company company;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  final _text = TextEditingController();
  final _ratings = {'overall': 4, 'workLife': 3, 'pay': 3, 'security': 3};
  bool _saving = false;
  String? _error;

  static const _labels = {
    'overall': 'Overall',
    'workLife': 'Work-life balance',
    'pay': 'Pay',
    'security': 'Job security',
  };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // Reviews must be about working/interviewing there and respectful.
    final text = _text.text.trim();
    if (text.isNotEmpty) {
      try {
        final problem = await ref.read(jobsApiProvider).checkText('review', text);
        if (problem != null) {
          if (mounted) {
            setState(() {
              _saving = false;
              _error = problem;
            });
          }
          return;
        }
      } catch (_) {
        // Server unreachable: the review is still moderated by the team.
      }
    }
    final profile = ref.read(profileDataProvider).value;
    final name = widget.company.name.toLowerCase();
    final entry = profile?.experience.entries.where((e) {
      final c = e.company.toLowerCase();
      return c.isNotEmpty && (name.contains(c) || c.contains(name.split(' ').first));
    }).firstOrNull;
    try {
      await ref.read(reviewsRepositoryProvider).save(
            uid: user.uid,
            company: widget.company,
            author: entry == null
                ? 'Student'
                : entry.type == 'internship'
                    ? 'Intern'
                    : 'Employee',
            workedThere: entry != null,
            overall: _ratings['overall']!,
            workLife: _ratings['workLife']!,
            pay: _ratings['pay']!,
            security: _ratings['security']!,
            text: _text.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save your review. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.pageGutter, AppSpacing.lg,
          AppSpacing.pageGutter, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Review ${widget.company.name}', style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Shown without your name. Be honest and respectful; reviews that '
              'break the Terms are hidden.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final key in _ratings.keys)
              Row(
                children: [
                  Expanded(child: Text(_labels[key]!, style: AppTypography.bodyMedium)),
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _ratings[key] = i),
                      icon: Icon(
                        i <= _ratings[key]! ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.botanicalGreen,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              maxLength: 800,
              decoration: const InputDecoration(
                labelText: 'Your experience (optional)',
                hintText: 'Interview process, culture, learning, workload…',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!, style: AppTypography.bodySmall),
              ),
            AppButton(label: 'Post review', isLoading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}


/// "What reviewers say": overall sentiment bar and the aspects people
/// mention (learning, pay, work-life …), from NLP analysis of the reviews.
class _SentimentCard extends ConsumerWidget {
  const _SentimentCard({required this.companyId});

  final String companyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(reviewAnalysisProvider(companyId)).value;
    if (a == null || a.reviews == 0) return const SizedBox.shrink();
    Color tone(String label) => switch (label) {
          'positive' => AppColors.botanicalGreen,
          'negative' => AppColors.charcoal,
          _ => AppColors.softSage,
        };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.botanicalGreen.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What reviewers say', style: AppTypography.labelLarge),
          const SizedBox(height: 2),
          Text(a.summary, style: AppTypography.bodySmall.copyWith(color: AppColors.charcoal)),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (a.positivePercent > 0)
                  Expanded(flex: a.positivePercent, child: Container(height: 8, color: AppColors.botanicalGreen)),
                if (a.neutralPercent > 0)
                  Expanded(flex: a.neutralPercent, child: Container(height: 8, color: AppColors.softSage)),
                if (a.negativePercent > 0)
                  Expanded(flex: a.negativePercent, child: Container(height: 8, color: AppColors.charcoal)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${a.positivePercent}% positive · ${a.neutralPercent}% mixed · '
            '${a.negativePercent}% negative',
            style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
          ),
          if (a.aspects.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final asp in a.aspects)
                  Tooltip(
                    message: asp.example,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: tone(asp.label)),
                      ),
                      child: Text(
                        '${asp.label == 'positive' ? '+' : asp.label == 'negative' ? '−' : '±'} '
                        '${asp.aspect}',
                        style: AppTypography.labelMedium.copyWith(color: tone(asp.label)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text('Analysed automatically from review text and ratings.',
              style: AppTypography.bodySmall.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
