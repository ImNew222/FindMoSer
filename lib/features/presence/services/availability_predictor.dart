import 'dart:math' as math;
import '../../attendance/models/schedule_model.dart';
import '../../../core/campus_time.dart';
import 'location_policy.dart';

class AvailabilityObservation {
  final DateTime recordedAt;
  final bool available;
  final bool inZone;
  final bool teaching;
  const AvailabilityObservation({
    required this.recordedAt,
    required this.available,
    required this.inZone,
    required this.teaching,
  });
}

class AvailabilityForecast {
  final String status;
  final String reason;
  final double? probability;
  final int samples;
  final int days;
  const AvailabilityForecast(
    this.status,
    this.reason, {
    this.probability,
    this.samples = 0,
    this.days = 0,
  });
  Map<String, dynamic> toMap() => {
    'status': status,
    'reason': reason,
    'probability': probability,
    'samples': samples,
    'days': days,
    'modelVersion': 'knn-pilot-v1',
  };
  String get label => switch (status) {
    'likely_available' => 'Likely available — confirm with faculty',
    'likely_unavailable' => 'Likely unavailable',
    'scheduled_class' => 'Class scheduled — availability not confirmed',
    _ => 'Availability uncertain',
  };
}

/// Pilot supervised k-nearest-neighbour classifier. Thresholds are provisional,
/// not validated accuracy claims. No labels are inferred from presence alone.
class AvailabilityPredictor {
  static const minimumSamples = 12;
  static const minimumDays = 3;
  static const neighbours = 5;
  static const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static bool teachingAt(List<ClassSchedule> schedule, DateTime instant) {
    final t = CampusTime.wallClock(instant);
    final minute = t.hour * 60 + t.minute;
    return schedule.any((s) {
      final start = LocationPolicy.minutes(s.startTime);
      final end = LocationPolicy.minutes(s.endTime);
      if (start == null || end == null) return false;
      final day = s.dayOfWeek.toLowerCase();
      bool matches(int weekday) =>
          day == days[weekday - 1].toLowerCase() ||
          day == days[weekday - 1].substring(0, 3).toLowerCase();
      if (end > start) {
        return matches(t.weekday) && minute >= start && minute < end;
      }
      if (end < start) {
        return matches(t.weekday) && minute >= start ||
            matches(t.weekday == 1 ? 7 : t.weekday - 1) && minute < end;
      }
      return false;
    });
  }

  AvailabilityForecast predict({
    required DateTime at,
    required DateTime knowledgeAt,
    required bool inZone,
    required List<ClassSchedule> schedule,
    required List<AvailabilityObservation> observations,
  }) {
    if (schedule.isEmpty) {
      return const AvailabilityForecast(
        'insufficient_data',
        'Class schedules have not been recorded.',
      );
    }
    if (teachingAt(schedule, at)) {
      return const AvailabilityForecast(
        'scheduled_class',
        'The timetable records a class in this interval. This is a schedule fallback, not a learned prediction.',
      );
    }
    final independent = <String, AvailabilityObservation>{};
    final sorted = [...observations]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    for (final o in sorted) {
      // Strictly past observations prevent evaluation leakage. Limit drift.
      if (!o.recordedAt.isBefore(knowledgeAt) ||
          knowledgeAt.difference(o.recordedAt) > const Duration(days: 60)) {
        continue;
      }
      final t = CampusTime.wallClock(o.recordedAt);
      independent['${t.year}-${t.month}-${t.day}-${(t.hour * 60 + t.minute) ~/ 30}'] =
          o;
    }
    final data = independent.values.toList();
    String dayKey(AvailabilityObservation o) =>
        CampusTime.wallClock(o.recordedAt).toIso8601String().substring(0, 10);
    final dayCount = data.map(dayKey).toSet().length;
    if (data.length < minimumSamples ||
        dayCount < minimumDays ||
        data.map((o) => o.available).toSet().length < 2) {
      return AvailabilityForecast(
        'insufficient_data',
        'Need at least 12 independent labelled intervals across 3 days, including available and unavailable examples.',
        samples: data.length,
        days: dayCount,
      );
    }
    final target = CampusTime.wallClock(at);
    double distance(AvailabilityObservation o) {
      final t = CampusTime.wallClock(o.recordedAt);
      final rawDay = (target.weekday - t.weekday).abs();
      final rawTime =
          ((target.hour * 60 + target.minute) - (t.hour * 60 + t.minute)).abs();
      return 0.25 * math.min(rawDay, 7 - rawDay) / 3 +
          0.35 * math.min(rawTime, 1440 - rawTime) / 720 +
          0.20 * (o.inZone == inZone ? 0 : 1) +
          0.20 * (o.teaching ? 1 : 0);
    }

    data.sort((a, b) {
      final score = distance(a).compareTo(distance(b));
      return score != 0 ? score : b.recordedAt.compareTo(a.recordedAt);
    });
    final nearby = <AvailabilityObservation>[];
    final perDay = <String, int>{};
    for (final o in data) {
      final key = dayKey(o);
      if (distance(o) > 0.35 || (perDay[key] ?? 0) >= 2) continue;
      nearby.add(o);
      perDay[key] = (perDay[key] ?? 0) + 1;
      if (nearby.length == neighbours) break;
    }
    final supportDays = nearby.map(dayKey).toSet().length;
    if (nearby.length < neighbours || supportDays < minimumDays) {
      return AvailabilityForecast(
        'low_confidence',
        'Too few comparable observations across different days. Ask the faculty member to confirm.',
        samples: nearby.length,
        days: supportDays,
      );
    }
    final p = nearby.where((o) => o.available).length / nearby.length;
    final status = p >= 0.8
        ? 'likely_available'
        : p <= 0.2
        ? 'likely_unavailable'
        : 'low_confidence';
    return AvailabilityForecast(
      status,
      'Agreement among ${nearby.length} comparable labelled observations across $supportDays days. This is an uncalibrated pilot estimate, not measured accuracy.',
      probability: p,
      samples: nearby.length,
      days: supportDays,
    );
  }
}
