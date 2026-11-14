import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../platform/web_bridge.dart';
import '../theme/theme.dart';
import 'app_button.dart';
import 'glass_popup.dart';

const _key = 'verixa.motionAsked';

/// iPhone web app only: asks once whether the leaves may follow the
/// phone's tilt (Safari needs the user's OK for motion data).
Future<void> maybeAskForMotion(BuildContext context) async {
  if (!kIsWeb || !needsMotionPermission || storageGet(_key) != null) return;
  storageSet(_key, 'asked');
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: AppColors.charcoal.withValues(alpha: 0.18),
    transitionDuration: AppMotion.page,
    pageBuilder: (context, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SizedBox(
          width: 360,
          child: GlassPanel(
            radius: AppRadius.lg + 8,
            frost: 1.4,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.screen_rotation_alt_outlined,
                      color: AppColors.botanicalGreen, size: 32),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Let the leaves follow your tilt?',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Safari will ask to use motion. It only moves the '
                    'background leaves; nothing is stored or sent.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Not now',
                          style: AppButtonStyle.outlined,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          label: 'Allow',
                          onPressed: () {
                            // Must start inside the tap for Safari.
                            requestMotionPermission();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}
