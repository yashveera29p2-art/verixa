import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/glass_nav_bar.dart';
import '../features/resume/presentation/resume_actions_sheet.dart';

/// Wraps the main tabs (Home, Profile) with the glass bottom bar.
/// The tab pages scroll underneath the bar so the blur is visible.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTabTap(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab again returns it to its first page.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: GlassNavBar(
          currentIndex: navigationShell.currentIndex,
          onTap: _onTabTap,
          onCentreTap: () => showResumeActionsSheet(context),
          left: const GlassNavItem(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
          ),
          right: const GlassNavItem(
            label: 'Profile',
            icon: Icons.person_outline,
            activeIcon: Icons.person,
          ),
        ),
      ),
    );
  }
}
