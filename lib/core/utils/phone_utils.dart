/// Helpers for phone number entry. India (+91) is the default market.
abstract final class PhoneUtils {
  static const defaultCountryCode = '+91';

  /// Keeps only digits.
  static String digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

  /// Normalises a country code to the form "+91".
  static String normaliseCountryCode(String input) => '+${digitsOnly(input)}';

  /// Builds an E.164 number such as "+919999999999".
  static String toE164(String countryCode, String number) =>
      '${normaliseCountryCode(countryCode)}${digitsOnly(number)}';

  /// Returns an error message, or null if the number looks valid.
  /// Indian mobiles are 10 digits starting with 6–9; other countries just
  /// need a plausible length (Firebase does the final check).
  static String? validate(String countryCode, String number) {
    final code = normaliseCountryCode(countryCode);
    final digits = digitsOnly(number);
    if (code.length < 2 || code.length > 4) return 'Enter a valid country code.';
    if (digits.isEmpty) return 'Enter your phone number.';
    if (code == defaultCountryCode) {
      if (digits.length != 10) return 'Indian mobile numbers have 10 digits.';
      if (!RegExp(r'^[6-9]').hasMatch(digits)) {
        return 'Indian mobile numbers start with 6, 7, 8 or 9.';
      }
      return null;
    }
    if (digits.length < 6 || digits.length > 14) return 'Enter a valid phone number.';
    return null;
  }

  /// "+919999999999" → "+91 99999 99999" for display.
  static String pretty(String e164) {
    if (e164.startsWith(defaultCountryCode) && e164.length == 13) {
      final n = e164.substring(3);
      return '$defaultCountryCode ${n.substring(0, 5)} ${n.substring(5)}';
    }
    return e164;
  }
}
