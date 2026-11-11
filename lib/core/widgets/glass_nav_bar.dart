import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// One side item of the bar (Home, Profile).
class GlassNavItem {
  const GlassNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Frosted-glass bottom bar (CLAUDE.md §3.3): translucent ivory with a
/// background blur and a thin stone border — no glow, no heavy shadow.
///
/// Layout: [left item] [larger centre circle] [right item].
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.left,
    required this.right,
    required this.currentIndex,
    required this.onTap,
    required this.onCentreTap,
    this.centreIcon = Icons.description_outlined,
    this.centreLabel = 'Resume actions',
  });

  final GlassNavItem left;
  final GlassNavItem right;

  /// 0 = left item active, 1 = right item active.
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCentreTap;
  final IconData centreIcon;
  final String centreLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppSizes.glassBlur,
          sigmaY: AppSizes.glassBlur,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ivory.withValues(alpha: AppSizes.glassOpacity),
            border: const Border(
              top: BorderSide(
                color: AppColors.stone,
                width: AppSizes.borderWidth,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: AppSizes.navBarHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _SideItem(
                      item: left,
                      active: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  _CentreButton(
                    icon: centreIcon,
                    label: centreLabel,
                    onTap: onCentreTap,
                  ),
                  Expanded(
                    child: _SideItem(
                      item: right,
                      active: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.botanicalGreen : AppColors.mutedText;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: Colors.transparent,
        splashColor: AppColors.softSage.withValues(alpha: 0.3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? item.activeIcon : item.icon,
              color: color,
              size: AppSizes.navIcon,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.label,
              style: AppTypography.labelMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The slightly larger botanical green circle in the middle of the bar.
class _CentreButton extends StatelessWidget {
  const _CentreButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Material(
          color: AppColors.botanicalGreen,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: AppSizes.navCentreButton,
              child: Icon(icon, color: AppColors.ivory, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}
