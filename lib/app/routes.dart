/// Route paths used across the app.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const welcome = '/welcome';

  /// Phone entry. Add `?mode=login` for "Log in" wording.
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const onboarding = '/onboarding';

  // Main tabs (inside the glass-nav shell).
  static const home = '/home';
  static const profile = '/profile';

  /// Company list for a category: /companies/mnc, /companies/sme, ...
  static const companies = '/companies';

  static String phoneFor({required bool isLogin}) =>
      isLogin ? '$phone?mode=login' : phone;

  static String companiesFor(String categoryId) => '$companies/$categoryId';

  /// Company detail: /companies/mnc/tcs
  static String companyDetail(String categoryId, String companyId) =>
      '$companies/$categoryId/$companyId';

  /// Profile section editor: /profile/edit/skills. With [guided], saving
  /// moves on to the next unfinished section.
  static String profileEdit(String sectionId, {bool guided = false}) =>
      '$profile/edit/$sectionId${guided ? '?guided=1' : ''}';

  /// True for routes that need a signed-in user.
  static bool isProtected(String path) =>
      path == onboarding ||
      path == home ||
      path == profile ||
      path.startsWith('$profile/') ||
      path.startsWith('$companies/');
}
