/// Checks for what people type into profile fields. Each returns an error
/// message to show under the field, or null when the value is fine.
/// Empty optional fields are fine.
abstract final class Validators {
  static final _letters = RegExp(r"^[A-Za-z][A-Za-z .'\-]*$");

  static String? personName(String v) {
    final s = v.trim();
    if (s.length < 2) return 'Please enter your full name.';
    if (!_letters.hasMatch(s) || !s.contains(RegExp('[A-Za-z]{2}'))) {
      return 'Use letters only (no numbers or symbols).';
    }
    return null;
  }

  /// City, state, board, college… : letters plus common punctuation.
  static String? placeName(String v, String what) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (!RegExp(r"^[A-Za-z][A-Za-z0-9 .,'&()\-]*$").hasMatch(s) ||
        !s.contains(RegExp('[A-Za-z]{2}'))) {
      return 'Enter a real $what.';
    }
    return null;
  }

  static String? linkedin(String v) => _link(v, RegExp(r'linkedin\.com/(in|pub)/[\w\-%.]+', caseSensitive: false),
      'Enter your LinkedIn profile link, e.g. linkedin.com/in/your-name');

  static String? github(String v) => _link(v, RegExp(r'github\.com/[\w\-]+', caseSensitive: false),
      'Enter your GitHub link, e.g. github.com/your-name');

  static String? website(String v) => _link(
      v,
      RegExp(r'^(https?://)?([\w\-]+\.)+[a-z]{2,}(/\S*)?$', caseSensitive: false),
      'Enter a website link, e.g. yourname.dev');

  static String? _link(String v, RegExp pattern, String message) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.contains(' ') || !pattern.hasMatch(s)) return message;
    return null;
  }

  /// CGPA out of 10.
  static String? cgpa(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null || n < 0 || n > 10) return 'CGPA should be between 0 and 10.';
    return null;
  }

  /// 10th / 12th / diploma marks: a percentage (0–100) or CGPA (0–10).
  static String? score(String v) {
    final s = v.trim().replaceAll('%', '');
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null || n < 0 || n > 100) return 'Enter a percentage (0–100) or CGPA (0–10).';
    return null;
  }

  static String? year(String v, {int from = 1980}) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    final max = DateTime.now().year + 6;
    if (n == null || n < from || n > max) return 'Enter a year between $from and $max.';
    return null;
  }

  static String? yearsOfExperience(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null || n < 0 || n > 50) return 'Enter years between 0 and 50.';
    return null;
  }
}
