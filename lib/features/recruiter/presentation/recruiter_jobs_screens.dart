import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/application/auth_providers.dart';
import '../../workstyle/workstyle.dart';
import '../application/recruiter_providers.dart';
import '../domain/recruiter_models.dart';

/// Post a job: shows in students' Jobs tab immediately.
class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _skills = TextEditingController();
  final _description = TextEditingController();
  JobType _type = JobType.fullTime;
  bool _unpaid = false;
  final _traits = <Trait>{};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _location, _min, _max, _skills, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _post() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    final account = ref.read(myRecruiterAccountProvider).value;
    if (uid == null || account == null) return;
    final min = double.tryParse(_min.text.trim()) ?? 0;
    final max = double.tryParse(_max.text.trim()) ?? min;
    if (_title.text.trim().isEmpty || _description.text.trim().length < 30) {
      setState(() => _error = 'Add a title and a description of at least a few lines.');
      return;
    }
    if (!_unpaid && max <= 0) {
      setState(() => _error = 'Enter the pay in LPA, or mark it as unpaid.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recruiterRepositoryProvider).postJob(PostedJob(
            id: '',
            ownerUid: uid,
            company: account.company,
            title: _title.text,
            location: _location.text,
            type: _type,
            payMinLpa: _unpaid ? 0 : min,
            payMaxLpa: _unpaid ? 0 : (max < min ? min : max),
            description: _description.text,
            skills: _skills.text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .take(20)
                .toList(),
            wantedTraits: {for (final t in _traits) t.name: 1.0},
          ));
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t post. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lpa = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return AuthPage(
      eyebrow: 'FOR RECRUITERS',
      title: 'Post a job',
      subtitle: const Text(
        'It appears in students’ Jobs tab right away, ranked for each '
        'student by how well they fit.',
      ),
      bottom: AppButton(label: 'Post job', isLoading: _saving, onPressed: _post),
      children: [
        LabeledTextField(controller: _title, label: 'Job title', hint: 'e.g. Backend Developer Intern'),
        const FormGroupLabel('Type'),
        ChoiceChips<JobType>(
          options: JobType.values,
          selected: _type,
          labelOf: (t) => t.label,
          onSelected: (t) => setState(() => _type = t),
        ),
        LabeledTextField(controller: _location, label: 'Location', hint: 'e.g. Bengaluru or Remote'),
        const FormGroupLabel('Pay (yearly, in lakhs)'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _unpaid,
          onChanged: (v) => setState(() => _unpaid = v),
          activeThumbColor: AppColors.botanicalGreen,
          title: Text('Unpaid', style: AppTypography.bodyMedium),
        ),
        if (!_unpaid)
          Row(
            children: [
              Expanded(
                child: LabeledTextField(
                  controller: _min,
                  label: 'From (LPA)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: lpa,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: LabeledTextField(
                  controller: _max,
                  label: 'To (LPA)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: lpa,
                ),
              ),
            ],
          ),
        LabeledTextField(
          controller: _skills,
          label: 'Key skills (comma-separated)',
          hint: 'Python, REST APIs, SQL',
        ),
        LabeledTextField(
          controller: _description,
          label: 'Description',
          hint: 'What they’ll do, what you need (required vs nice to have)…',
          maxLines: 8,
          maxLength: 4000,
        ),
        const FormGroupLabel('Work style you value (optional)'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final t in Trait.values)
              FilterChip(
                label: Text(t.label),
                selected: _traits.contains(t),
                onSelected: (on) => setState(() => on ? _traits.add(t) : _traits.remove(t)),
                showCheckmark: false,
                selectedColor: AppColors.botanicalGreen,
                backgroundColor: AppColors.white,
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: _traits.contains(t) ? AppColors.ivory : AppColors.charcoal,
                ),
              ),
          ],
        ),
        InlineError(_error),
      ],
    );
  }
}

/// The recruiter's posted jobs and shortlist.
class MyJobsScreen extends ConsumerWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myPostedJobsProvider).value ?? const <PostedJob>[];
    final shortlist = ref.watch(shortlistProvider).value ?? const [];
    final repo = ref.read(recruiterRepositoryProvider);
    final navInset = AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.pageGutter, AppSpacing.lg,
              AppSpacing.pageGutter, navInset + AppSpacing.lg),
          children: [
            Row(
              children: [
                Expanded(child: Text('My jobs', style: AppTypography.displayMedium)),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.welcome);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (jobs.isEmpty)
              Text('No jobs yet. Tap + to post your first job.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
            for (final j in jobs) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.stone),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.title, style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                    Text('${j.type.label} · ${j.payText}${j.location.isEmpty ? '' : ' · ${j.location}'}',
                        style: AppTypography.bodySmall),
                    if (j.hidden)
                      Text('Hidden by the Verixa team', style: AppTypography.bodySmall),
                    _InterestedCount(jobId: j.id),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete this job?'),
                              content: const Text('Students will no longer see it.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) await repo.deleteJob(j.id);
                        },
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Shortlist', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            if (shortlist.isEmpty)
              Text('Star candidates in Find talent to keep them here.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
            for (final s in shortlist)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.star_rounded, color: AppColors.botanicalGreen),
                title: Text(s['fullName'] as String? ?? '', style: AppTypography.labelLarge),
                subtitle: Text(
                  [s['headline'], s['jobTitle']]
                      .whereType<String>()
                      .where((x) => x.isNotEmpty)
                      .join(' · '),
                  style: AppTypography.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InterestedCount extends ConsumerWidget {
  const _InterestedCount({required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder(
      stream: ref
          .watch(firestoreProvider)
          .collection('jobs')
          .doc(jobId)
          .collection('interested')
          .snapshots(),
      builder: (context, snap) {
        final n = snap.data?.docs.length ?? 0;
        return Text(
          n == 0 ? 'No interested students yet' : '$n interested student${n == 1 ? '' : 's'}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.botanicalGreen),
        );
      },
    );
  }
}
