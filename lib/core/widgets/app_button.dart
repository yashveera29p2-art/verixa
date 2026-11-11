import 'package:flutter/material.dart';

import '../theme/theme.dart';

enum AppButtonStyle { filled, outlined }

/// Full-width button in the Verixa style.
///
/// Set [onDark] when the button sits on a botanical green section: the
/// colours invert (ivory fill / ivory outline). [isLoading] shows a small
/// spinner and disables the button.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.onDark = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final bool onDark;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final accent = onDark ? AppColors.ivory : AppColors.botanicalGreen;
    final onAccent = onDark ? AppColors.botanicalGreen : AppColors.ivory;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const size = Size.fromHeight(AppSizes.buttonHeight);
    final callback = isLoading ? null : onPressed;
    final child = isLoading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: style == AppButtonStyle.filled ? onAccent : accent,
            ),
          )
        : Text(label);

    final button = switch (style) {
      AppButtonStyle.filled => FilledButton(
        onPressed: callback,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: isLoading ? accent : AppColors.softSage,
          disabledForegroundColor: onAccent,
          minimumSize: size,
          shape: shape,
          textStyle: AppTypography.button,
          elevation: 0,
        ),
        child: child,
      ),
      AppButtonStyle.outlined => OutlinedButton(
        onPressed: callback,
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: size,
          shape: shape,
          textStyle: AppTypography.button,
          side: BorderSide(color: accent, width: AppSizes.borderWidth),
        ),
        child: child,
      ),
    };
    return PressScale(enabled: callback != null, child: button);
  }
}
