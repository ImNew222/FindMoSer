/// Cebu campus wall clock (UTC+8, no daylight-saving time).
/// Use the original instant for age comparisons and this clock for schedules.
class CampusTime {
  static String dateKey(DateTime instant) {
    final cebu = wallClock(instant);
    return '${cebu.year}-${cebu.month.toString().padLeft(2, '0')}-${cebu.day.toString().padLeft(2, '0')}';
  }

  static DateTime wallClock(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));
}
