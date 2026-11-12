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
      // Owns the background aurora's clock and reacts to every touch.
      builder: (context, child) => AuroraScope(child: child!),
    );
  }
}
