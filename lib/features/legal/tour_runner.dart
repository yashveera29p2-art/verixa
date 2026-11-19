import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/guided_tour.dart';
import '../auth/application/auth_providers.dart';
import '../recruiter/application/recruiter_providers.dart';

/// Bumped by About -> 'Take the tour again'; the shells listen to it.
final replayTour = ValueNotifier<int>(0);

/// Plays the guided tour [tour] if this user hasn't seen it on this
/// installation, then remembers it.
Future<void> maybeRunTour(
  BuildContext context,
  WidgetRef ref,
  String tour,
  List<TourStep> steps, {
  bool force = false,
}) async {
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  if (uid == null) return;
  final consent = ref.read(consentRepositoryProvider);
  try {
    if (!force && await consent.tourDone(uid, tour)) return;
  } catch (_) {
    return; // offline: try again next launch
  }
  if (!context.mounted) return;
  await showGuidedTour(context, steps);
  try {
    await consent.markTourDone(uid, tour);
  } catch (_) {}
}

/// Drop into any screen to play that screen's guide the first time it
/// opens on this installation. Draws nothing.
class PageTour extends ConsumerStatefulWidget {
  const PageTour({
    super.key,
    required this.name,
    required this.steps,
    this.delay = const Duration(milliseconds: 800),
  });

  final String name;
  final List<TourStep> Function() steps;

  /// Lets page transitions and entrance animations finish first.
  final Duration delay;

  @override
  ConsumerState<PageTour> createState() => _PageTourState();
}

class _PageTourState extends ConsumerState<PageTour> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) maybeRunTour(context, ref, widget.name, widget.steps());
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
