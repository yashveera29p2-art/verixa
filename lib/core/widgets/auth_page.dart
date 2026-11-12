import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// Shared layout for the sign-in and onboarding screens: back button,
/// serif title, supporting text, scrollable form, and a bottom action.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.bottom,
    this.showBack = true,
    this.eyebrow,
    this.actions,
  });

  final String title;
  final Widget subtitle;
  final List<Widget> children;
  final Widget bottom;
  final bool showBack;

  /// Small label above the title, e.g. "Step 1 of 1".
  final String? eyebrow;

  /// Optional app bar buttons (e.g. a history icon).
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: showBack, actions: actions),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageGutter,
                    AppSpacing.xs,
                    AppSpacing.pageGutter,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (eyebrow != null) ...[
                        Text(
                          eyebrow!.toUpperCase(),
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.botanicalGreen),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      // Each block arrives a moment after the previous one.
                      StaggeredEntrance(
                        index: 0,
                        child: Text(title, style: AppTypography.headlineLarge),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      StaggeredEntrance(
                        index: 1,
                        child: DefaultTextStyle.merge(
                          style: AppTypography.bodyLarge
                              .copyWith(color: AppColors.mutedText),
                          child: subtitle,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      for (var i = 0; i < children.length; i++)
                        StaggeredEntrance(index: i + 2, child: children[i]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  0,
                  AppSpacing.pageGutter,
                  AppSpacing.md,
                ),
                child: StaggeredEntrance(
                  index: children.length + 2,
                  child: bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline error line used under form fields.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      alignment: Alignment.topLeft,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: AppColors.charcoal),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.charcoal),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
