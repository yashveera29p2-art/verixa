import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/links.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/auth_page.dart';
import '../auth/application/auth_providers.dart';
import '../auth/application/session.dart';
import '../recruiter/application/recruiter_providers.dart';
import 'legal.dart';

/// Shown once per installation after signing in: a short summary of the
/// Terms, a link to the full document, and "I agree".
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _agreed = false;
  bool _saving = false;
  String? _error;

  static const _points = [
    'Verixa helps you prepare. It does not guarantee a job, an interview, '
        'a shortlist or any result.',
    'Company information, pay, layoff and work-life notes, ATS scores and '
        'match scores are estimates from public information and our models. '
        'They can be wrong or out of date.',
    'Verixa is an independent academic project. It is not affiliated with '
        'or endorsed by any company shown in the app.',
    'You are responsible for keeping your profile and resumes truthful. '
        'Do not add skills or experience you do not have.',
    'Recruiters only see you if you switch on “Visible to recruiters”. '
        'Job listings may come from third parties such as Adzuna.',
    'Do not misuse the app: no fake profiles, fake recruiter accounts or '
        'harmful reviews. Accounts that do this can be removed.',
  ];

  Future<void> _accept() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(consentRepositoryProvider)
          .acceptTerms(user.uid)
          .timeout(const Duration(seconds: 15));
      final next = await routeForUser(ref.read, user);
      if (mounted) context.go(next == AppRoutes.terms ? AppRoutes.home : next);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn’t save. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AuthPage(
        title: 'Before you start',
        showBack: false,
        subtitle: const Text(
          'Please read and accept the Terms of use. Here are the key points:',
        ),
        bottom: AppButton(
          label: 'Accept and continue',
          isLoading: _saving,
          onPressed: _agreed ? _accept : null,
        ),
        children: [
          for (var i = 0; i < _points.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.botanicalGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.ivory, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _points[i],
                      style: AppTypography.bodyMedium.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openLink(Legal.termsUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Read the full Terms of use'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.botanicalGreen,
                textStyle: AppTypography.labelLarge,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(
                color: _agreed ? AppColors.botanicalGreen : AppColors.stone,
              ),
            ),
            child: CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              activeColor: AppColors.botanicalGreen,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I have read and agree to the Terms of use (version '
                '${Legal.termsVersion}).',
                style: AppTypography.bodyMedium,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _error!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.charcoal),
              ),
            ),
        ],
      ),
    );
  }
}
