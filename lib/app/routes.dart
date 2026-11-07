/// Route paths used across the app.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const welcome = '/welcome';

  /// Phone entry. Add `?mode=login` for "Log in" wording.
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const onboarding = '/onboarding';
  static const home = '/home';

  static String phoneFor({required bool isLogin}) =>
      isLogin ? '$phone?mode=login' : phone;

  /// Routes that need a signed-in user.
  static const protected = {onboarding, home};
}
