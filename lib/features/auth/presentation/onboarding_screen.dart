import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../application/auth_providers.dart';
import '../application/onboarding_controller.dart';
import '../domain/user_profile.dart';

/// Step 3 (new users only): name, status, and college or company.
/// Everything else is collected later from Profile.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _orgController = TextEditingController();
  UserStatus? _status;
  bool _showErrors = false;

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  String? get _nameError => _nameController.text.trim().length < 2
      ? 'Please enter your full name.'
      : null;

  String? get _statusError => _status == null ? 'Choose one option.' : null;

  String? get _orgError => _orgController.text.trim().isEmpty
      ? (_status?.asksForCompany ?? false
          ? 'Please enter your company.'
          : 'Please enter your college.')
      : null;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    if (_nameError != null || _statusError != null || _orgError != null) {
      return;
    }
    final saved = await ref.read(onboardingControllerProvider.notifier).save(
          fullName: _nameController.text,
          status: _status!,
          organisation: _orgController.text,
        );
    if (saved && mounted) context.go(AppRoutes.home);
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(onboardingControllerProvider);
    final asksCompany = _status?.asksForCompany ?? false;
    final saveError = saving.hasError
        ? 'Couldn’t save your details. Check your connection and try again.'
        : null;

    return AuthPage(
      showBack: false,
      eyebrow: 'Almost done',
      title: 'A little about you',
      subtitle: const Text(
          'This helps us tailor resume advice. You can add the rest later '
          'from your profile.'),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InlineError(saveError),
          if (saveError != null) const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Continue',
            isLoading: saving.isLoading,
            onPressed: _submit,
          ),
          TextButton(
            onPressed: saving.isLoading ? null : _signOut,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.mutedText,
              textStyle: AppTypography.labelLarge,
            ),
            child: const Text('Use a different number'),
          ),
        ],
      ),
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Full name',
            errorText: _showErrors ? _nameError : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('I am a…', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        for (final status in UserStatus.values) ...[
          _StatusOption(
            status: status,
            selected: _status == status,
            onTap: () => setState(() => _status = status),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (_showErrors) InlineError(_statusError),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _orgController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          style: AppTypography.bodyLarge,
          decoration: InputDecoration(
            labelText: asksCompany ? 'Company' : 'College',
            hintText: asksCompany
                ? 'e.g. Infosys'
                : 'e.g. JNTU Hyderabad',
            errorText: _showErrors ? _orgError : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
      ],
    );
  }
}

/// A selectable row; the chosen one fills with botanical green.
class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final UserStatus status;
  final bool selected;
  final VoidCallback onTap;

  static const _icons = {
    UserStatus.student: Icons.school_outlined,
    UserStatus.fresher: Icons.workspace_premium_outlined,
    UserStatus.workingProfessional: Icons.work_outline,
  };

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.ivory : AppColors.charcoal;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.botanicalGreen : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: selected ? AppColors.botanicalGreen : AppColors.stone,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(_icons[status], color: fg, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(status.label,
                      style: AppTypography.labelLarge
                          .copyWith(fontSize: 16, color: fg)),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? AppColors.ivory : AppColors.stone,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
