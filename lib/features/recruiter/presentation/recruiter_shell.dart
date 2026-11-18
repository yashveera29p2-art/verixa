import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../app/tour_keys.dart';
import '../../../core/widgets/glass_nav_bar.dart';
import '../../legal/tour_runner.dart';

/// Recruiter tabs (Find talent, My jobs) with "Post a job" in the centre,
/// over the same falling-leaves background as the student side.
class RecruiterShell extends ConsumerStatefulWidget {
  const RecruiterShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<RecruiterShell> createState() => _RecruiterShellState();
}

class _RecruiterShellState extends ConsumerState<RecruiterShell> {
  @override
  void initState() {
    super.initState();
    replayTour.addListener(_replay);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) maybeRunTour(context, ref, 'recruiter', TourKeys.recruiter);
    });
  }

  void _replay() {
    widget.navigationShell.goBranch(0);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) maybeRunTour(context, ref, 'recruiter', TourKeys.recruiter, force: true);
    });
  }

  @override
  void dispose() {
    replayTour.removeListener(_replay);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
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
            onTap: (i) => widget.navigationShell.goBranch(
              i,
              initialLocation: i == widget.navigationShell.currentIndex,
            ),
            onCentreTap: () => context.push(AppRoutes.recruiterPost),
            centreIcon: Icons.add,
            centreLabel: 'Post a job',
            centreTourKey: TourKeys.postButton,
            items: [
              GlassNavItem(
                label: 'Find talent',
                icon: Icons.person_search_outlined,
                activeIcon: Icons.person_search,
                tourKey: TourKeys.talentTab,
              ),
              GlassNavItem(
                label: 'My jobs',
                icon: Icons.work_outline,
                activeIcon: Icons.work,
                tourKey: TourKeys.myJobsTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
