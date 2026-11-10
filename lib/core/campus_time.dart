/// Cebu campus wall clock (UTC+8, no daylight-saving time).
/// Use the original instant for age comparisons and this clock for schedules.
class CampusTime {
  static String dateKey(DateTime instant) {
    final cebu = wallClock(instant);
    return '${cebu.year}-${cebu.month.toString().padLeft(2, '0')}-${cebu.day.toString().padLeft(2, '0')}';
  }

  static DateTime wallClock(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));

  /// User-facing 12-hour AM/PM clock in Cebu time.
  /// Firestore storage and CSV exports stay 24-hour/ISO.
  static String clock12(DateTime instant) => _format(wallClock(instant));

  /// Converts a stored 24-hour 'HH:mm' schedule value to 'h:mm AM/PM'.
  static String hhmm12(String hhmm) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (match == null) return hhmm;
    return _format(
      DateTime(2000, 1, 1, int.parse(match.group(1)!), int.parse(match.group(2)!)),
    );
  }

  static String _format(DateTime t) {
    final period = t.hour < 12 ? 'AM' : 'PM';
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$hour12:${t.minute.toString().padLeft(2, '0')} $period';
  }
}
