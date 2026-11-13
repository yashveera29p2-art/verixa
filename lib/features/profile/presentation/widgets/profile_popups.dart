import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/install_counter.dart' show appVersion;
import '../../../../core/utils/phone_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_popup.dart';

/// Asks "Sign out?" in a glass bar that grows out of the Sign out button.
/// Returns true if the user confirmed.
Future<bool> confirmSignOut(BuildContext button) async {
  final ok = await showGlassPopup<bool>(
    origin: button,
    size: (s) => Size((s.width - 2 * AppSpacing.lg).clamp(0, 420), 168),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          Text('Sign out of Verixa?', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Your profile and resumes stay saved to your number.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: AppColors.mutedText),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  style: AppButtonStyle.outlined,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Sign out',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Account and app details, floating over the Profile tab and growing out
/// of the "About" capsule. Frostier glass than the nav bar.
Future<void> showAboutPanel(
  BuildContext button, {
  required String name,
  required String? phone,
  required String? gmail,
}) {
  return showGlassPopup<void>(
    origin: button,
    radius: AppRadius.lg + 8,
    frost: 1.5,
    rimWidth: 2,
    size: (s) =>
        Size((s.width - 2 * AppSpacing.lg).clamp(0, 460), s.height * 0.75),
    builder: (context) => _AboutContent(name: name, phone: phone, gmail: gmail),
  );
}

class _AboutContent extends StatelessWidget {
  const _AboutContent({
    required this.name,
    required this.phone,
    required this.gmail,
  });

  final String name;
  final String? phone;
  final String? gmail;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? 'V' : letters;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.charcoal),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.botanicalGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials,
                    style: AppTypography.headlineLarge.copyWith(
                      color: AppColors.ivory,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                name.isEmpty ? 'Your account' : name,
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('ACCOUNT'),
              _Row(
                icon: Icons.phone_iphone_outlined,
                label: 'Phone',
                value: phone == null ? '—' : PhoneUtils.pretty(phone!),
              ),
              _Row(
                icon: Icons.mail_outline,
                label: 'Gmail',
                value: gmail ?? 'Not linked',
                muted: gmail == null,
              ),
              const SizedBox(height: AppSpacing.md),
              const _Label('APP'),
              const _Row(
                icon: Icons.info_outline,
                label: 'Version',
                value: appVersion,
              ),
              const SizedBox(height: AppSpacing.md),
              const _Label('CREDITS'),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.botanicalGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.botanicalGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Built by',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      "Team Tok3n's",
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.botanicalGreen,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'under the mentorship of',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                    Text(
                      'Dr. Nandu Chandran Nair',
                      textAlign: TextAlign.center,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.charcoal,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      text,
      style: AppTypography.labelMedium.copyWith(color: AppColors.mutedText),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.botanicalGreen),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.labelLarge),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(
                color: muted ? AppColors.mutedText : AppColors.charcoal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
