import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../application/phone_auth_controller.dart';

/// Step 1: enter a phone number (+91 by default) and request an OTP.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({
    super.key,
    this.isLogin = false,
    this.alreadyRegistered = false,
    this.initialPhone,
  });

  /// "Log in" vs "Create account". Both use the same phone flow, but
  /// "Create account" first checks the number isn't already registered.
  final bool isLogin;

  /// Came here from "Create account" with a number that already has an
  /// account: shows a short note above the field.
  final bool alreadyRegistered;

  /// E.164 number to prefill (e.g. +919876543210).
  final String? initialPhone;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _codeController = TextEditingController(
    text: PhoneUtils.defaultCountryCode,
  );
  final _numberController = TextEditingController();
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final phone = widget.initialPhone;
    const cc = PhoneUtils.defaultCountryCode;
    if (phone != null && phone.startsWith(cc) && phone.length > cc.length) {
      _numberController.text = phone.substring(cc.length);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final error = PhoneUtils.validate(
      _codeController.text,
      _numberController.text,
    );
    setState(() => _validationError = error);
    if (error != null) return;

    final phone = PhoneUtils.toE164(
      _codeController.text,
      _numberController.text,
    );
    final controller = ref.read(phoneAuthControllerProvider.notifier);
    if (!widget.isLogin && await controller.isExistingAccount(phone)) {
      // Already registered: switch to "Log in" with the number filled in.
      if (mounted) {
        context.pushReplacement(AppRoutes.phoneExisting, extra: phone);
      }
      return;
    }
    if (!mounted) return;
    final outcome = await ref
        .read(phoneAuthControllerProvider.notifier)
        .sendCode(phone);
    if (!mounted) return;
    switch (outcome) {
      case CodeSent():
        context.push(AppRoutes.otp);
      case SignedIn(:final route):
        context.go(route);
      case SendFailed():
        break; // Error is shown from controller state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final error = _validationError ?? state.error;

    return AuthPage(
      title: widget.isLogin ? 'Welcome back' : 'Create your account',
      subtitle: Text(
        widget.isLogin
            ? 'Enter the phone number you signed up with. We’ll text you a '
                  '6-digit code.'
            : 'Your phone number is your Verixa account. We’ll text you a '
                  '6-digit code to confirm it.',
      ),
      bottom: AppButton(
        label: 'Send code',
        isLoading: state.isBusy,
        onPressed: _submit,
      ),
      children: [
        if (widget.alreadyRegistered) ...[
          const _ExistingAccountNote(),
          const SizedBox(height: AppSpacing.md),
        ],
        Text('Phone number', style: AppTypography.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.phone,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => _clearErrors(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _numberController,
                autofocus: true,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                style: AppTypography.bodyLarge.copyWith(letterSpacing: 1),
                decoration: const InputDecoration(hintText: '98765 43210'),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                onChanged: (_) => _clearErrors(),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        InlineError(error),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Standard SMS rates may apply. Gmail is optional — you can link it '
          'later from your profile.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }

  void _clearErrors() {
    if (_validationError != null) setState(() => _validationError = null);
    ref.read(phoneAuthControllerProvider.notifier).clearError();
  }
}

/// "This number already has an account" note on the log-in screen.
class _ExistingAccountNote extends StatelessWidget {
  const _ExistingAccountNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.botanicalGreen),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.botanicalGreen,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'You already have a Verixa account with this number. '
              'Log in to continue.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.charcoal,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
