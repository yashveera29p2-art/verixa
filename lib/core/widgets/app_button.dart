import 'package:flutter/material.dart';

import '../theme/theme.dart';

enum AppButtonStyle { filled, outlined }

/// Full-width button in the Verixa style.
///
/// Set [onDark] when the button sits on a botanical green section: the
/// colours invert (ivory fill / ivory outline).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.onDark = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final accent = onDark ? AppColors.ivory : AppColors.botanicalGreen;
    final onAccent = onDark ? AppColors.botanicalGreen : AppColors.ivory;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const size = Size.fromHeight(AppSizes.buttonHeight);

    return switch (style) {
      AppButtonStyle.filled => FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: onAccent,
            minimumSize: size,
            shape: shape,
            textStyle: AppTypography.button,
            elevation: 0,
          ),
          child: Text(label),
        ),
      AppButtonStyle.outlined => OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            minimumSize: size,
            shape: shape,
            textStyle: AppTypography.button,
            side: BorderSide(color: accent, width: AppSizes.borderWidth),
          ),
          child: Text(label),
        ),
    };
  }
}
