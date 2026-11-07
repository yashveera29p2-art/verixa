import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../../../core/widgets/otp_input.dart';
import '../application/phone_auth_controller.dart';

/// Step 2: type the 6-digit code. Submits automatically when complete.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _codeLength = 6;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  PhoneAuthController get _controller =>
      ref.read(phoneAuthControllerProvider.notifier);

  Future<void> _verify() async {
    final code = _codeController.text;
    if (code.length != _codeLength) return;
    final route = await _controller.verifyCode(code);
    if (!mounted) return;
    if (route != null) {
      context.go(route);
    } else {
      _codeController.clear();
      setState(() {});
    }
  }

  Future<void> _resend() async {
    _codeController.clear();
    final outcome = await _controller.resendCode();
    if (!mounted) return;
    switch (outcome) {
      case CodeSent():
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('New code sent.')));
      case SignedIn(:final route):
        context.go(route);
      case SendFailed():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneAuthControllerProvider);
    final phone = state.phoneNumber;

    return AuthPage(
      title: 'Enter the code',
      subtitle: Text.rich(TextSpan(children: [
        const TextSpan(text: 'We sent a 6-digit code to '),
        TextSpan(
          text: phone == null ? 'your phone' : PhoneUtils.pretty(phone),
          style: AppTypography.labelLarge
              .copyWith(fontSize: 16, color: AppColors.charcoal),
        ),
        const TextSpan(text: '.'),
      ])),
      bottom: AppButton(
        label: 'Verify',
        isLoading: state.isBusy,
        onPressed: _codeController.text.length == _codeLength ? _verify : null,
      ),
      children: [
        OtpInput(
          controller: _codeController,
          length: _codeLength,
          hasError: state.error != null,
          enabled: !state.isBusy,
          onChanged: (_) {
            _controller.clearError();
            setState(() {});
          },
          onCompleted: (_) => _verify(),
        ),
        InlineError(state.error),
        const SizedBox(height: AppSpacing.lg),
        _ResendRow(
          secondsLeft: state.resendSecondsLeft,
          enabled: state.canResend,
          onResend: _resend,
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: state.isBusy ? null : () => context.pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.botanicalGreen,
              textStyle: AppTypography.labelLarge,
              padding: EdgeInsets.zero,
            ),
            child: const Text('Change phone number'),
          ),
        ),
      ],
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.enabled,
    required this.onResend,
  });

  final int secondsLeft;
  final bool enabled;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (secondsLeft > 0) {
      final time = '0:${secondsLeft.toString().padLeft(2, '0')}';
      return Text('Resend code in $time',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedText));
    }
    return Row(
      children: [
        Text('Didn’t get it? ',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.mutedText)),
        TextButton(
          onPressed: enabled ? onResend : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.botanicalGreen,
            textStyle: AppTypography.labelLarge,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Resend code'),
        ),
      ],
    );
  }
}
