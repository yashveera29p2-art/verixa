import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';

/// Decides where the app goes after the splash. Read as soon as the splash
/// starts, so the answer is ready when the animation finishes.
///
/// Phase 1: everyone goes to Welcome.
/// Phase 2: check the Firebase Auth session here and return
/// [AppRoutes.home] for signed-in users.
final startupDestinationProvider = FutureProvider<String>((ref) async {
  return AppRoutes.welcome;
});
