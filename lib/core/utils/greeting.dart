/// Time-of-day greeting from CLAUDE.md §4, based on the phone's local time:
/// 04:00–11:59 morning, 12:00–16:59 afternoon, 17:00–03:59 evening.
String greetingFor(DateTime localTime) {
  final hour = localTime.hour;
  if (hour >= 4 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Good morning, Asha" — or "Good morning" when the name isn't known yet.
String greetingWithName(DateTime localTime, String? firstName) {
  final greeting = greetingFor(localTime);
  final name = firstName?.trim();
  return (name == null || name.isEmpty) ? greeting : '$greeting, $name';
}
