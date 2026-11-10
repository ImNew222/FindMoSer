import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_session_model.dart';
import '../../../core/campus_time.dart';

/// Refreshes time-sensitive UI even when Firestore has no new snapshots.
/// Firestore request.time remains authoritative for attendance acceptance.
final campusClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});

/// Select the date before notifying dependents so queries only change at
/// midnight in Cebu, rather than restarting on every clock tick.
final campusDateProvider = Provider<String>((ref) {
  return ref.watch(
    campusClockProvider.select(
      (clock) => CampusTime.dateKey(clock.value ?? DateTime.now()),
    ),
  );
});

bool isSessionOpenAt(AttendanceSession session, DateTime instant) =>
    session.status == 'open' && instant.isBefore(session.closesAt);
