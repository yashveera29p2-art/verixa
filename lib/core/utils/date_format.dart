/// Small date formatting helpers (no intl package needed).
abstract final class DateFormatting {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "11 Nov 2026"
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  /// "11 Nov 2026, 5:23 pm"
  static String dateTime(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '${date(d)}, $hour:$minute ${d.hour < 12 ? 'am' : 'pm'}';
  }
}
