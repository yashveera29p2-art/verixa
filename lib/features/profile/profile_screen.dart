import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_button.dart';
import '../auth/application/auth_providers.dart';

/// Placeholder Profile tab. The full step-by-step profile (CLAUDE.md §5)
/// is built in Phase 5.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final user = ref.watch(authStateProvider).value;
    final navInset =
        AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.xl,
            AppSpacing.pageGutter,
            navInset + AppSpacing.lg,
          ),
          children: [
            Text('Profile', style: AppTypography.displayMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your full profile — education, projects, skills and more — '
              'arrives in Phase 5.',
              style:
                  AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.xl),
            _AccountCard(
              name: profile?.fullName,
              phone: user?.phoneNumber,
              status: profile?.status.label,
              organisation: profile?.organisation,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Sign out',
              style: AppButtonStyle.outlined,
              onPressed: () => _signOut(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botanical green summary card of the signed-in account.
class _AccountCard extends StatelessWidget {
  const _AccountCard({this.name, this.phone, this.status, this.organisation});

  final String? name;
  final String? phone;
  final String? status;
  final String? organisation;

  @override
  Widget build(BuildContext context) {
    final muted = AppTypography.bodyMedium
        .copyWith(color: AppColors.ivory.withValues(alpha: 0.8));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name ?? 'Your account',
                style:
                    AppTypography.titleLarge.copyWith(color: AppColors.ivory)),
            const SizedBox(height: AppSpacing.sm),
            if (phone != null) Text(PhoneUtils.pretty(phone!), style: muted),
            if (status != null && organisation != null)
              Text('$status · $organisation', style: muted),
          ],
        ),
      ),
    );
  }
}
