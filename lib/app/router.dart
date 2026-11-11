import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/onboarding_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/phone_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/companies/domain/company_category.dart';
import '../features/companies/presentation/category_screen.dart';
import '../features/companies/presentation/company_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/domain/profile_section.dart';
import '../features/profile/presentation/editors/profile_edit_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/resume/presentation/resume_import_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/splash/splash_timings.dart';
import 'app_shell.dart';
import 'routes.dart';

export 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.splash,
    // Simple guard: signed-out users can't open the main app.
    // Which page a signed-in user lands on is decided by the splash and
    // the OTP screen (see features/auth/application/session.dart).
    redirect: (context, state) {
      final signedIn = ref.read(authServiceProvider).currentUser != null;
      if (!signedIn && AppRoutes.isProtected(state.matchedLocation)) {
        return AppRoutes.welcome;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        pageBuilder: (context, state) =>
            _fadePage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.phone,
        builder: (context, state) => PhoneScreen(
          isLogin: state.uri.queryParameters['mode'] == 'login',
        ),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            _fadePage(state, const OnboardingScreen()),
      ),

      // Main tabs with the glass bottom bar. Each tab keeps its own
      // navigation stack and scroll position.
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) =>
            _fadePage(state, AppShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
              routes: [
                // Full-screen editors, above the bottom bar.
                GoRoute(
                  path: 'edit/:section',
                  parentNavigatorKey: _rootKey,
                  redirect: (context, state) => ProfileSection.fromId(
                              state.pathParameters['section']) ==
                          null
                      ? AppRoutes.profile
                      : null,
                  builder: (context, state) => ProfileEditScreen(
                    section:
                        ProfileSection.fromId(state.pathParameters['section'])!,
                    guided: state.uri.queryParameters['guided'] == '1',
                  ),
                ),
              ],
            ),
          ]),
        ],
      ),

      GoRoute(
        path: AppRoutes.resumeImport,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ResumeImportScreen(),
      ),

      // Full-screen pages opened from Home (above the bottom bar).
      GoRoute(
        path: '${AppRoutes.companies}/:category',
        parentNavigatorKey: _rootKey,
        redirect: (context, state) =>
            CompanyCategory.fromId(state.pathParameters['category']) == null
                ? AppRoutes.home
                : null,
        builder: (context, state) => CategoryScreen(
          category: CompanyCategory.fromId(state.pathParameters['category'])!,
        ),
        routes: [
          GoRoute(
            path: ':companyId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) => CompanyDetailScreen(
              companyId: state.pathParameters['companyId']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// Fade transition used when leaving the splash and between top-level areas.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: SplashTimings.fadeOut,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
