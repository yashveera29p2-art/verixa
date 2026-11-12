import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/company.dart';
import 'company_avatar.dart';

/// One row in a category's company list: initials, name, sector and a
/// one-line summary of what they look for.
class CompanyTile extends StatelessWidget {
  const CompanyTile({super.key, required this.company, required this.onTap});

  final Company company;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompanyAvatar(initials: company.initials, domain: company.logoDomain),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company.name,
                        style: AppTypography.labelLarge.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        company.sector,
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.botanicalGreen,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        company.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: Icon(Icons.chevron_right, color: AppColors.softSage),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
