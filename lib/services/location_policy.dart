import '../models/location_model.dart';
import '../models/user_model.dart';
import 'campus_time.dart';

/// Shared policy for cards, assistant answers and collection of location data.
class LocationPolicy {
  static const freshFor = Duration(minutes: 5);

  static bool isFresh(FacultyLocation location, DateTime now) {
    final age = now.difference(location.timestamp);
    return !age.isNegative && age < freshFor;
  }

  static int? minutes(String? time) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time ?? '');
    if (match == null) return null;
    final h = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    return h < 24 && m < 60 ? h * 60 + m : null;
  }

  static bool withinHours(AppUser user, DateTime now) {
    final start = minutes(user.workStartTime);
    final end = minutes(user.workEndTime);
    final unconfigured =
        (user.workStartTime == null || user.workStartTime!.isEmpty) &&
        (user.workEndTime == null || user.workEndTime!.isEmpty);
    if (unconfigured) return true;
    if (start == null || end == null) return false;
    final local = CampusTime.wallClock(now);
    final current = local.hour * 60 + local.minute;
    if (start == end) return true;
    return start < end
        ? current >= start && current < end
        : current >= start || current < end;
  }

  static bool canShare(AppUser user, FacultyLocation? location, DateTime now) =>
      location != null && location.isVisible && withinHours(user, now);

  static String availabilityLabel(String value) => switch (value) {
    'available' => 'Available for consultation',
    'teaching' => 'Teaching',
    'busy' => 'Do not disturb',
    _ => 'Availability not set',
  };
}
