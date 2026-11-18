import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/auth_page.dart';
import '../../../core/widgets/form_fields.dart';
import '../../auth/application/auth_providers.dart';
import '../application/recruiter_providers.dart';
import '../domain/recruiter_models.dart';

/// New recruiter: name, company, designation and work email. The account
/// then waits for the Verixa team's approval.
class RecruiterSetupScreen extends ConsumerStatefulWidget {
  const RecruiterSetupScreen({super.key});

  @override
  ConsumerState<RecruiterSetupScreen> createState() => _RecruiterSetupScreenState();
}

class _RecruiterSetupScreenState extends ConsumerState<RecruiterSetupScreen> {
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _designation = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _company, _designation, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final email = _email.text.trim();
    if (_name.text.trim().isEmpty || _company.text.trim().isEmpty ||
        _designation.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid work email address.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(recruiterRepositoryProvider).requestAccount(RecruiterAccount(
            uid: user.uid,
            fullName: _name.text,
            company: _company.text,
            designation: _designation.text,
            workEmail: email,
            phone: user.phoneNumber ?? '',
          ));
      if (mounted) context.go(AppRoutes.recruiterPending);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t send your request. Check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      eyebrow: 'FOR RECRUITERS',
      title: 'Set up your recruiter account',
      showBack: false,
      subtitle: const Text(
        'The Verixa team checks every recruiter before they can see '
        'students. Use your company details; a work email helps us verify '
        'you faster.',
      ),
      bottom: AppButton(label: 'Request access', isLoading: _saving, onPressed: _submit),
      children: [
        LabeledTextField(controller: _name, label: 'Your full name'),
        LabeledTextField(controller: _company, label: 'Company'),
        LabeledTextField(
          controller: _designation,
          label: 'Designation',
          hint: 'e.g. Talent Acquisition Lead',
        ),
        LabeledTextField(
          controller: _email,
          label: 'Work email',
          hint: 'name@company.com',
          keyboardType: TextInputType.emailAddress,
        ),
        InlineError(_error),
        TextButton(
          onPressed: () async {
            await ref.read(authServiceProvider).signOut();
            if (context.mounted) context.go(AppRoutes.welcome);
          },
          child: const Text('Not a recruiter? Sign out'),
        ),
      ],
    );
  }
}

/// Waiting for the Verixa team to approve the recruiter account. Moves on
/// by itself as soon as it's approved.
class RecruiterPendingScreen extends ConsumerWidget {
  const RecruiterPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myRecruiterAccountProvider).value;
    ref.listen(myRecruiterAccountProvider, (_, next) {
      if (next.value?.status == RecruiterStatus.approved) {
        context.go(AppRoutes.recruiterTalent);
      }
    });
    final rejected = account?.status == RecruiterStatus.rejected;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pageGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Icon(
                  rejected ? Icons.block_outlined : Icons.hourglass_top_rounded,
                  size: 48,
                  color: AppColors.botanicalGreen,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  rejected ? 'Access not approved' : 'Waiting for approval',
                  style: AppTypography.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  rejected
                      ? 'The Verixa team couldn’t verify this recruiter account. '
                          'If you think this is a mistake, contact the team from '
                          'the Terms page.'
                      : 'Thanks${account == null ? '' : ', ${account.fullName.split(' ').first}'}. '
                          'The Verixa team is checking your details'
                          '${account == null ? '' : ' (${account.company})'}. '
                          'This page opens your recruiter dashboard as soon as '
                          'you’re approved.',
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
                ),
                const Spacer(flex: 2),
                AppButton(
                  label: 'Sign out',
                  style: AppButtonStyle.outlined,
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.welcome);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
