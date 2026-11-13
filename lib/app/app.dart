import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme.dart';
import '../core/widgets/aurora_background.dart';
import 'router.dart';

class VerixaApp extends ConsumerWidget {
  const VerixaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Verixa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      // One ivory + drifting-green background behind every screen; pages
      // are transparent and sit on top of it.
      builder: (context, child) => AuroraScope(
        child: AuroraBackground(child: child!),
      ),
    );
  }
}
