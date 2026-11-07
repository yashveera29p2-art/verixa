import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_button.dart';
import '../auth/application/auth_providers.dart';

/// Placeholder Home for Phase 2. The real Home (greeting, MNC/SME/Startup
/// cards, glass nav bar) is built in Phase 3.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authServiceProvider).signOut();
    if (context.mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final user = ref.watch(authStateProvider).value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Text(
                  profile.when(
                    data: (p) => p == null ? 'Hello' : 'Hello, ${p.firstName}',
                    loading: () => 'Hello',
                    error: (_, _) => 'Hello',
                  ),
                  style: AppTypography.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'You’re signed in. Home arrives in Phase 3.',
                  style: AppTypography.bodyLarge
                      .copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: AppSpacing.xl),
                _AccountCard(
                  phone: user?.phoneNumber,
                  status: profile.value?.status.label,
                  organisation: profile.value?.organisation,
                ),
                const Spacer(),
                AppButton(
                  label: 'Sign out',
                  style: AppButtonStyle.outlined,
                  onPressed: () => _signOut(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botanical green summary card of the signed-in account.
class _AccountCard extends StatelessWidget {
  const _AccountCard({this.phone, this.status, this.organisation});

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
            Text('Your account',
                style: AppTypography.titleLarge
                    .copyWith(color: AppColors.ivory)),
            const SizedBox(height: AppSpacing.sm),
            if (phone != null)
              Text(PhoneUtils.pretty(phone!), style: muted),
            if (status != null && organisation != null)
              Text('$status · $organisation', style: muted),
          ],
        ),
      ),
    );
  }
}
