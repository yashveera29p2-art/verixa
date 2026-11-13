import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/greeting.dart';
import '../auth/application/auth_providers.dart';
import '../companies/domain/company_category.dart';
import 'widgets/category_card.dart';

/// Home: time-of-day greeting and the three company-type cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(currentProfileProvider).value?.firstName;
    final navInset = AppSizes.navBarHeight + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pageGutter,
            AppSpacing.xl,
            AppSpacing.pageGutter,
            navInset + AppSpacing.lg,
          ),
          children: [
            _Greeting(firstName: firstName),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Where are you applying? Pick a company type to see what they '
              'look for and how to shape your resume.',
              style: AppTypography.bodyLarge.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'COMPANY TYPES',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Bento: MNC wide on top, SME and Startup as two squares below.
            CategoryCard(
              category: CompanyCategory.mnc,
              onTap: () => _open(context, CompanyCategory.mnc),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: AppSizes.bentoTileHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in const [
                    CompanyCategory.sme,
                    CompanyCategory.startup,
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: CategoryCard(
                        category: c,
                        square: true,
                        onTap: () => _open(context, c),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Good morning, Asha" — re-checks the clock every minute so the
/// greeting changes if the app stays open across 12:00, 17:00 or 04:00.
class _Greeting extends StatefulWidget {
  const _Greeting({required this.firstName});

  final String? firstName;

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      if (greetingFor(now) != greetingFor(_now)) setState(() => _now = now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      greetingWithName(_now, widget.firstName),
      style: AppTypography.displayMedium,
    );
  }
}

void _open(BuildContext context, CompanyCategory c) =>
    context.push(AppRoutes.companiesFor(c.id));
