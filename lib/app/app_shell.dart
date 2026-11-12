import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/glass_nav_bar.dart';
import '../features/resume/presentation/resume_branch_menu.dart';

/// Wraps the main tabs (Home, Profile) with the floating glass pill.
/// The tab pages scroll underneath the pill so the blur is visible.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _menuOpen = false;

  void _onTabTap(int index) {
    widget.navigationShell.goBranch(
      index,
      // Tapping the active tab again returns it to its first page.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _openMenu() async {
    setState(() => _menuOpen = true);
    await showResumeBranchMenu(context);
    if (mounted) setState(() => _menuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: GlassNavBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTabTap,
          onCentreTap: _openMenu,
          centreOpen: _menuOpen,
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
