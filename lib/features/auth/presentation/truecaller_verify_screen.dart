import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../application/truecaller_controller.dart';

/// Step 2 (Android): Truecaller confirms the number. Truecaller users tap
/// once; everyone else gets a missed call that the app detects by itself,
/// or a code by SMS.
class TruecallerVerifyScreen extends ConsumerStatefulWidget {
  const TruecallerVerifyScreen({super.key, required this.phone});

  /// E.164 number, e.g. +919876543210.
  final String phone;

  @override
  ConsumerState<TruecallerVerifyScreen> createState() =>
      _TruecallerVerifyScreenState();
}

class _TruecallerVerifyScreenState
    extends ConsumerState<TruecallerVerifyScreen> {
  final _otp = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _otp.clear();
    ref.read(truecallerControllerProvider.notifier).start(widget.phone);
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(truecallerControllerProvider, (_, next) {
      if (next.step == TcStep.done && next.route != null) {
        context.go(next.route!);
      }
    });
    final s = ref.watch(truecallerControllerProvider);
    final number = PhoneUtils.pretty(widget.phone);

    return AuthPage(
      title: 'Confirm your number',
      subtitle: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Verifying '),
            TextSpan(
              text: number,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const TextSpan(
              text: ' with Truecaller. It’s free and takes a moment.',
            ),
          ],
        ),
      ),
      bottom: switch (s.step) {
        TcStep.enterOtp => AppButton(
          label: 'Verify',
          onPressed: () => _submitOtp(),
        ),
        TcStep.failed => AppButton(label: 'Try again', onPressed: _start),
        _ => const SizedBox.shrink(),
      },
      children: [
        _StatusCard(state: s, number: number),
        if (s.step == TcStep.enterOtp) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _otp,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(hintText: '••••••'),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onChanged: (v) {
              if (v.length == 6) _submitOtp();
            },
          ),
        ],
        if (s.step == TcStep.failed) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text('Use a different number'),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Verification is powered by Truecaller. You don’t need the '
          'Truecaller app.',
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }

  void _submitOtp() {
    final code = _otp.text.trim();
    if (code.length < 4) return;
    FocusScope.of(context).unfocus();
    ref.read(truecallerControllerProvider.notifier).submitOtp(code);
  }
}

/// One card that says what's happening right now.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.number});

  final TcState state;
  final String number;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (state.step) {
      TcStep.starting => (
        Icons.hourglass_top_rounded,
        'Getting ready…',
        'If Android asks about phone calls, tap Allow so Verixa can spot '
            'Truecaller’s missed call.',
      ),
      TcStep.consent => (
        Icons.touch_app_outlined,
        'Confirm in Truecaller',
        'Tap Continue on the Truecaller sheet to share your verified number.',
      ),
      TcStep.waitingCall => (
        Icons.phone_callback_outlined,
        'Expect a missed call',
        'Truecaller is calling $number. Don’t answer it — Verixa confirms '
            'your number automatically. (${state.secondsLeft}s)',
      ),
      TcStep.enterOtp => (
        Icons.sms_outlined,
        'Enter the code',
        'Truecaller sent a code by SMS to $number. Type it below. '
            '(${state.secondsLeft}s)',
      ),
      TcStep.checking || TcStep.done => (
        Icons.verified_user_outlined,
        'Confirming…',
        'Signing you in to Verixa.',
      ),
      TcStep.failed => (
        Icons.error_outline_rounded,
        'Not confirmed',
        state.error ?? 'Couldn’t verify your number. Please try again.',
      ),
    };
    final busy = state.step == TcStep.starting || state.step == TcStep.checking;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: state.step == TcStep.failed
              ? AppColors.charcoal
              : AppColors.botanicalGreen,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.botanicalGreen,
                  ),
                )
              : Icon(icon, color: AppColors.botanicalGreen),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelLarge),
                const SizedBox(height: 4),
                Text(body, style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
