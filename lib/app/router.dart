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
import '../features/resume/presentation/cover_letter_screen.dart';
import '../features/resume/presentation/jd_match_screen.dart';
import '../features/resume/presentation/match_history_screens.dart';
import '../features/resume/presentation/resume_import_screen.dart';
import '../features/resume/presentation/new_resume_screen.dart';
import '../features/resume/presentation/resume_editor_screen.dart';
import '../features/resume/presentation/resume_preview_screen.dart';
import '../features/resume/presentation/resume_scan_screen.dart';
import '../features/resume/presentation/resumes_screen.dart';
import '../features/resume/presentation/scan_detail_screen.dart';
import '../features/resume/presentation/scan_history_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/splash/splash_timings.dart';
import '../core/theme/theme.dart';
import '../features/splash/splash_exit.dart';
import '../core/widgets/aurora_background.dart';
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
        builder: (context, state) =>
            PhoneScreen(isLogin: state.uri.queryParameters['mode'] == 'login'),
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
      StatefulShellRoute(
        pageBuilder: (context, state, shell) =>
            _fadePage(state, AppShell(navigationShell: shell), withNav: true),
        // Fade-through when switching between Home and Profile.
        navigatorContainerBuilder: (context, shell, children) =>
            FadeThroughStack(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  // Full-screen editors, above the bottom bar.
                  GoRoute(
                    path: 'edit/:section',
                    parentNavigatorKey: _rootKey,
                    redirect: (context, state) =>
                        ProfileSection.fromId(
                              state.pathParameters['section'],
                            ) ==
                            null
                        ? AppRoutes.profile
                        : null,
                    builder: (context, state) => ProfileEditScreen(
                      section: ProfileSection.fromId(
                        state.pathParameters['section'],
                      )!,
                      guided: state.uri.queryParameters['guided'] == '1',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.resumeImport,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            ResumeImportScreen(initial: state.extra as ImportArgs?),
      ),
      GoRoute(
        path: AppRoutes.resumeScan,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ResumeScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.jdMatch,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const JdMatchScreen(),
      ),
      GoRoute(
        path: AppRoutes.matchHistory,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const MatchHistoryScreen(),
        routes: [
          GoRoute(
            path: ':matchId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) =>
                MatchDetailScreen(matchId: state.pathParameters['matchId']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.resumeNew,
        parentNavigatorKey: _rootKey,
        builder: (context, state) =>
            NewResumeScreen(companyId: state.uri.queryParameters['company']),
      ),
      GoRoute(
        path: AppRoutes.resumes,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ResumesScreen(),
        routes: [
          GoRoute(
            path: ':resumeId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) =>
                ResumeEditorScreen(id: state.pathParameters['resumeId']!),
            routes: [
              GoRoute(
                path: 'preview',
                parentNavigatorKey: _rootKey,
                builder: (context, state) =>
                    ResumePreviewScreen(id: state.pathParameters['resumeId']!),
              ),
              GoRoute(
                path: 'cover',
                parentNavigatorKey: _rootKey,
                builder: (context, state) =>
                    CoverLetterScreen(id: state.pathParameters['resumeId']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.scanHistory,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const ScanHistoryScreen(),
        routes: [
          GoRoute(
            path: ':scanId',
            parentNavigatorKey: _rootKey,
            builder: (context, state) =>
                ScanDetailScreen(scanId: state.pathParameters['scanId']!),
          ),
        ],
      ),

      // Full-screen pages opened from Home (above the bottom bar).
      GoRoute(
        path: '${AppRoutes.companies}/:category',
        parentNavigatorKey: _rootKey,
        redirect: (context, state) =>
            CompanyCategory.fromId(state.pathParameters['category']) == null
            ? AppRoutes.home
            : null,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 520),
          reverseTransitionDuration: const Duration(milliseconds: 420),
          // Fade only: the category card's Hero does the visible motion.
          transitionsBuilder: (context, animation, secondary, child) =>
              _coverFade(secondary, FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              )),
          child: CategoryScreen(
            category: CompanyCategory.fromId(state.pathParameters['category'])!,
          ),
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

/// Transition for top-level areas: right after the splash, the splash's
/// exit plays over this page ([withNav]: the V lands in the nav bar's
/// centre button); otherwise a fade.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child,
    {bool withNav = false}) {
  if (SplashExit.claim(state.pageKey)) {
    if (withNav) SplashExit.navIntro = true;
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: SplashExit.duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        animation.addStatusListener((s) {
          if (s == AnimationStatus.completed) SplashExit.clear();
        });
        return Stack(
          fit: StackFit.expand,
          children: [
            // Its own light background during the exit, so the green splash
            // page underneath can't tint the screen while it fades away.
            AuroraBackground(child: _coverFade(secondaryAnimation, child)),
            SplashExitOverlay(animation: animation, withNav: withNav),
          ],
        );
      },
    );
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: SplashTimings.fadeOut,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        _coverFade(
          secondaryAnimation,
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: AppMotion.enter),
            child: child,
          ),
        ),
  );
}

/// Fades a page out while another page opens over it (and back in when
/// that page closes). Pages are transparent over the shared background, so
/// without this the covered page would show through the new one.
Widget _coverFade(Animation<double> secondary, Widget child) => FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: secondary,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
        reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
      )),
      child: child,
    );
