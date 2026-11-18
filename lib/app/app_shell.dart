import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/glass_nav_bar.dart';
import '../features/legal/tour_runner.dart';
import 'tour_keys.dart';
import '../core/widgets/motion_prompt.dart';
import '../features/resume/presentation/resume_branch_menu.dart';
import '../features/splash/splash_exit.dart';

/// Wraps the student tabs (Home, Jobs, Prep, Profile) with the floating
/// glass pill.
/// The tab pages scroll underneath the pill so the blur is visible.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _menuOpen = false;

  /// Pop the pill out of the centre button when we've just left the splash.
  final bool _playIntro = SplashExit.takeNavIntro();

  @override
  void initState() {
    super.initState();
    // After the nav intro: the guided tour (once per installation), then
    // on the iPhone web app the tilt-reactive leaves offer.
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      await maybeRunTour(context, ref, 'student', TourKeys.student);
      if (mounted) await maybeAskForMotion(context);
    });
    replayTour.addListener(_replay);
  }

  void _replay() {
    widget.navigationShell.goBranch(0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) maybeRunTour(context, ref, 'student', TourKeys.student, force: true);
    });
  }

  @override
  void dispose() {
    replayTour.removeListener(_replay);
    super.dispose();
  }

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
      // Back on any tab other than Home returns to Home instead of closing
      // the app.
      child: PopScope(
        canPop: widget.navigationShell.currentIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.navigationShell.goBranch(0);
        },
        child: Scaffold(
          extendBody: true,
          body: widget.navigationShell,
          bottomNavigationBar: GlassNavBar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _onTabTap,
            onCentreTap: _openMenu,
            centreOpen: _menuOpen,
            playIntro: _playIntro,
            introDelay: SplashExit.navIntroDelay,
            centreTourKey: TourKeys.resumeButton,
            items: [
              GlassNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                tourKey: TourKeys.homeTab,
              ),
              GlassNavItem(
                label: 'Jobs',
                icon: Icons.work_outline,
                activeIcon: Icons.work,
                tourKey: TourKeys.jobsTab,
              ),
              GlassNavItem(
                label: 'Prep',
                icon: Icons.school_outlined,
                activeIcon: Icons.school,
                tourKey: TourKeys.prepTab,
              ),
              GlassNavItem(
                label: 'Profile',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                tourKey: TourKeys.profileTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
