import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/verixa_monogram.dart';

/// First screen for signed-out users. Buttons are wired up in Phase 2.
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
              AppButton(
                label: 'Create account',
                onDark: true,
                onPressed: () {}, // Phase 2: phone sign-up
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Log in',
                style: AppButtonStyle.outlined,
                onDark: true,
                onPressed: () {}, // Phase 2: phone login
              ),
            ],
          ),
        ),
      ),
    );
  }
}
