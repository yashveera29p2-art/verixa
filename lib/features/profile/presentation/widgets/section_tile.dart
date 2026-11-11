import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/profile_section.dart';

/// One profile section row: icon, title, status text and a done marker.
class SectionTile extends StatelessWidget {
  const SectionTile({
    super.key,
    required this.section,
    required this.isComplete,
    required this.summary,
    required this.onTap,
  });

  final ProfileSection section;
  final bool isComplete;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.stone),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppColors.botanicalGreen
                      : AppColors.softSage.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  section.icon,
                  size: 22,
                  color: isComplete ? AppColors.ivory : AppColors.botanicalGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: AppTypography.labelLarge.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      style: AppTypography.bodySmall.copyWith(
                        color: isComplete
                            ? AppColors.botanicalGreen
                            : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isComplete ? Icons.check_circle : Icons.chevron_right,
                color: isComplete ? AppColors.botanicalGreen : AppColors.softSage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
