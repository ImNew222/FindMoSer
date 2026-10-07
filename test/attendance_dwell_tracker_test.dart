import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/services/attendance_dwell_tracker.dart';

void main() {
  final start = DateTime.utc(2026, 10, 7, 1);
  late AttendanceDwellTracker tracker;
  setUp(() => tracker = AttendanceDwellTracker(expectedRoom: 'Room305'));

  void reading(
    int seconds, {
    String beacon = 'esp32-a',
    String room = 'Room305',
    int rssi = -65,
  }) {
    final time = start.add(Duration(seconds: seconds));
    tracker.observe(
      beaconKey: beacon,
      roomId: room,
      rssi: rssi,
      observedAt: time,
      now: time,
    );
  }

  test('15 seconds needs fresh continuous advertisements at the threshold', () {
    for (var second = 0; second < 15; second++) {
      reading(second, rssi: -70);
      expect(tracker.complete, isFalse);
    }
    reading(15, rssi: -70);
    expect(tracker.complete, isTrue);
    expect(tracker.verifiedDuration, const Duration(seconds: 15));
  });

  test('a timer and duplicated cached advertisement cannot finish a dwell', () {
    reading(0);
    reading(2);
    final same = start.add(const Duration(seconds: 2));
    expect(
      tracker.observe(
        beaconKey: 'esp32-a',
        roomId: 'Room305',
        rssi: -40,
        observedAt: same,
        now: start.add(const Duration(seconds: 3)),
      ),
      isFalse,
    );
    expect(tracker.verifiedDuration, const Duration(seconds: 2));
    expect(tracker.expire(start.add(const Duration(seconds: 6))), isTrue);
    expect(tracker.complete, isFalse);
    expect(tracker.hasEvidence, isFalse);
  });

  test(
    'weak or invalid signal restarts evidence from the next valid reading',
    () {
      for (var second = 0; second <= 10; second++) {
        reading(second);
      }
      reading(11, rssi: -71);
      expect(tracker.hasEvidence, isFalse);
      reading(12);
      expect(tracker.verifiedDuration, Duration.zero);
      reading(13, rssi: 1);
      expect(tracker.hasEvidence, isFalse);
    },
  );

  test('a different room can never count toward the requested room', () {
    reading(0);
    reading(1);
    reading(2, room: 'Room306');
    expect(tracker.hasEvidence, isFalse);
    for (var second = 3; second <= 20; second++) {
      reading(second, room: 'room305');
    }
    expect(tracker.complete, isFalse);
  });

  test('switching physical beacon identity restarts even in the same room', () {
    for (var second = 0; second <= 10; second++) {
      reading(second);
    }
    reading(11, beacon: 'esp32-b');
    expect(tracker.beaconKey, 'esp32-b');
    expect(tracker.verifiedDuration, Duration.zero);
  });

  test('a gap beyond 3 seconds restarts even if expiry timer was delayed', () {
    reading(0);
    reading(3);
    expect(tracker.verifiedDuration, const Duration(seconds: 3));
    reading(7);
    expect(tracker.verifiedDuration, Duration.zero);
    expect(tracker.complete, isFalse);
  });

  test('future, stale and out-of-order advertisements cannot add evidence', () {
    reading(0);
    reading(2);
    for (final seconds in [-2, 1, 5]) {
      expect(
        tracker.observe(
          beaconKey: 'esp32-a',
          roomId: 'Room305',
          rssi: -50,
          observedAt: start.add(Duration(seconds: seconds)),
          now: start.add(const Duration(seconds: 3)),
        ),
        isFalse,
      );
    }
    expect(tracker.verifiedDuration, const Duration(seconds: 2));
    expect(tracker.complete, isFalse);
  });

  test(
    'clock rollback invalidates evidence instead of preserving progress',
    () {
      reading(0);
      reading(2);
      expect(tracker.expire(start.add(const Duration(seconds: 1))), isTrue);
      expect(tracker.hasEvidence, isFalse);
    },
  );

  test('diagnostics may select a room but cannot combine rooms', () {
    tracker = AttendanceDwellTracker();
    reading(0, room: 'Room306');
    reading(2, room: 'Room306');
    reading(3, room: 'Room305');
    expect(tracker.roomId, 'Room305');
    expect(tracker.verifiedDuration, Duration.zero);
    tracker.reset();
    expect(tracker.roomId, isNull);
    expect(tracker.rssi, isNull);
  });
}
