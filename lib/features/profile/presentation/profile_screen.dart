import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_providers.dart';
import '../application/profile_providers.dart';
import '../domain/profile_data.dart';
import '../domain/profile_section.dart';
import 'widgets/completion_card.dart';
import 'widgets/section_tile.dart';

/// Profile tab: completion indicator plus the step-by-step sections
/// from CLAUDE.md §5.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileDataProvider);
    final phone = ref.watch(authStateProvider).value?.phoneNumber;
    final navInset =
        AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profile.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.botanicalGreen),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Text(
              'Couldn’t load your profile. Check your connection.',
              style: AppTypography.bodyLarge
                  .copyWith(color: AppColors.mutedText),
            ),
          ),
          data: (data) => ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.xl,
              AppSpacing.pageGutter,
              navInset + AppSpacing.lg,
            ),
            children: [
              if (data != null) ...[
                _Header(data: data, phone: phone),
                const SizedBox(height: AppSpacing.lg),
                CompletionCard(
                  completion: data.completion,
                  completedCount: data.completedCoreCount,
                  next: data.nextIncomplete,
                  onContinue: () => context.push(AppRoutes.profileEdit(
                    data.nextIncomplete!.id,
                    guided: true,
                  )),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('YOUR PROFILE',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.mutedText)),
                const SizedBox(height: AppSpacing.sm),
                for (final section in ProfileSection.values) ...[
                  SectionTile(
                    section: section,
                    isComplete: data.isComplete(section),
                    summary: data.summaryFor(section),
                    onTap: () =>
                        context.push(AppRoutes.profileEdit(section.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('RESUMES',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.mutedText)),
                const SizedBox(height: AppSpacing.sm),
                _LinkTile(
                  icon: Icons.history,
                  title: 'Scan history',
                  subtitle: 'Past security scans and ATS scores',
                  onTap: () => context.push(AppRoutes.scanHistory),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Sign out',
                style: AppButtonStyle.outlined,
                onPressed: () => _signOut(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.phone});

  final ProfileData data;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final org = data.statusDetails.organisation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.contact.fullName.isEmpty ? 'Profile' : data.contact.fullName,
          style: AppTypography.displayMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          [
            data.status.label,
            if (org.isNotEmpty) org,
            if (phone != null) PhoneUtils.pretty(phone!),
          ].join(' · '),
          style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText),
        ),
      ],
    );
  }
}

/// A plain navigation row, e.g. "Scan history".
class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.stone),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: AppColors.botanicalGreen),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                    Text(subtitle, style: AppTypography.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.softSage),
            ],
          ),
        ),
      ),
    );
  }
}
