import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';

/// The company's logo, loaded from its website's icon (via Google's public
/// favicon service), on a white tile. Shows the initials badge while it
/// loads or when there's no internet.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({
    super.key,
    required this.initials,
    this.domain,
    this.size = 48,
  });

  final String initials;

  /// e.g. "tcs.com"; null shows the initials.
  final String? domain;
  final double size;

  static String logoUrl(String domain) =>
      'https://www.google.com/s2/favicons?sz=128&domain=$domain';

  @override
  Widget build(BuildContext context) {
    final badge = _InitialsBadge(initials: initials, size: size);
    if (domain == null) return badge;
    return SizedBox.square(
      dimension: size,
      child: Image.network(
        logoUrl(domain!),
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        // Fade the logo in over the badge once it arrives.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return _LogoTile(size: size, child: child);
          return Stack(
            children: [
              badge,
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: AppMotion.medium,
                child: _LogoTile(size: size, child: child),
              ),
            ],
          );
        },
        errorBuilder: (context, error, stack) => badge,
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.stone),
      ),
      child: child,
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.initials, required this.size});

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
