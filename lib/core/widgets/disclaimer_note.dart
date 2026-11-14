import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Small, quiet "please note" line: info icon and muted text.
/// Used for disclaimers (estimates, non-affiliation, privacy).
class DisclaimerNote extends StatelessWidget {
  const DisclaimerNote(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 15, color: AppColors.mutedText),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mutedText,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The texts, kept together so they stay consistent across screens.
abstract final class Disclaimers {
  static const notAffiliated =
      'Verixa is an independent academic project, not affiliated with or '
      'endorsed by any company shown. Company names and logos belong to '
      'their respective owners and are used only to identify them.';

  static const companyGuidance =
      'General guidance based on public hiring patterns — not an official '
      'statement from the company, and hiring criteria change. Always '
      'check the actual job posting.';

  static const scan =
      'Findings come from automated checks and can be wrong in either '
      'direction. Review them yourself before acting. Your file is read in '
      'memory and not stored on our server.';

  static const match =
      'The match score is an estimate from your profile and the text you '
      'pasted. It doesn’t predict shortlisting or selection.';

  static const genuineResume =
      'Verixa builds resumes only from details you enter. You are '
      'responsible for keeping them accurate and truthful before you send '
      'them.';

  static const coverLetter =
      'A starting draft from your profile. Read it carefully and make sure '
      'everything is true and fits the job before sending.';

  static const importPrivacy =
      'Your file is read in memory on our server to find your details and '
      'is not stored. Check imported fields — automatic reading can make '
      'mistakes.';
}
