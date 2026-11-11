import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

/// Logo placeholder: the company's initials (no scraped logos).
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({super.key, required this.initials, this.size = 48});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.botanicalGreen,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        initials,
        style: AppTypography.titleLarge.copyWith(
          color: AppColors.ivory,
          fontSize: size * 0.4,
          height: 1,
        ),
      ),
    );
  }
}
