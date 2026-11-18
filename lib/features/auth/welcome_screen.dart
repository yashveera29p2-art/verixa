import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/verixa_monogram.dart';
import 'application/session.dart';
import 'domain/user_profile.dart';

/// First screen for signed-out users. Both buttons lead to the phone OTP
/// flow; only the wording differs.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Intro()),
            _ActionsPanel(),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.xl,
          AppSpacing.pageGutter,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const VerixaMonogram(height: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('Verixa', style: AppTypography.titleLarge),
              ],
            ),
            const Spacer(),
            Text(
              'Resumes that are\ngenuinely yours.',
              style: AppTypography.displayMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Build ATS-friendly resumes, check them for hidden tricks, '
              'and tailor them for MNCs, SMEs and startups.',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botanical green section holding the two entry buttons.
class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel();

  void _start(BuildContext context, UserRole role, {required bool login}) {
    SignInIntent.role = role;
    context.push(AppRoutes.phoneFor(isLogin: login, recruiter: role == UserRole.recruiter));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.xl,
            AppSpacing.pageGutter,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Get started',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.ivory,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in with your phone number. You can link Gmail later.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.ivory.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Create account',
                      onDark: true,
                      onPressed: () => _start(context, UserRole.student, login: false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Log in',
                      style: AppButtonStyle.outlined,
                      onDark: true,
                      onPressed: () => _start(context, UserRole.student, login: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Recruiters: same phone sign-in, then their own setup.
              Material(
                color: AppColors.ivory.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(color: AppColors.ivory.withValues(alpha: 0.35)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _start(context, UserRole.recruiter, login: false),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, color: AppColors.ivory),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I’m a recruiter',
                                style: AppTypography.labelLarge
                                    .copyWith(color: AppColors.ivory),
                              ),
                              Text(
                                'Find students by skills and work style',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.ivory.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: AppColors.ivory, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
