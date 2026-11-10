import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:findmoser_app/features/attendance/models/attendance_model.dart';
import 'package:findmoser_app/features/attendance/services/attendance_outbox.dart';

AttendanceRecord _receipt(String id, {String uid = 'student-one'}) =>
    AttendanceRecord(
      id: id,
      studentId: uid,
      studentName: 'Student One',
      facultyId: 'faculty-one',
      classId: 'class-one',
      sessionId: 'session-one',
      subject: 'Programming',
      beaconId: 'FindMoSer_Room305',
      roomId: 'Room305',
      zoneName: 'Room305',
      rssi: -64,
      dwellSeconds: 15,
      deviceId: '0123456789abcdef',
      localTimestamp: DateTime.utc(2026, 10, 8, 1),
      date: '2026-10-08',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'pending and rejected receipts survive reconstructing the outbox',
    () async {
      final outbox = AttendanceOutbox();
      await outbox.put(_receipt('pending'));
      await outbox.put(
        _receipt('rejected').copyWith(
          syncStatus: SyncStatus.failed,
          failureReason: 'Session closed before upload.',
        ),
      );
      final restored = await AttendanceOutbox().read('student-one');
      expect(restored.map((r) => r.id), ['pending', 'rejected']);
      expect(restored.first.isSynced, false);
      expect(restored.last.syncStatus, SyncStatus.failed);
      expect(restored.last.failureReason, 'Session closed before upload.');
      expect(
        restored.last.localTimestamp.toUtc(),
        DateTime.utc(2026, 10, 8, 1),
      );
    },
  );

  test(
    'concurrent mutations preserve receipts and emit account-scoped changes',
    () async {
      final outbox = AttendanceOutbox();
      final changes = outbox.changes.take(3).toList();
      await Future.wait([
        outbox.put(_receipt('first')),
        outbox.put(_receipt('second')),
        outbox.remove('student-one', 'first'),
      ]);
      expect((await outbox.read('student-one')).map((r) => r.id), ['second']);
      expect(await changes, ['student-one', 'student-one', 'student-one']);
    },
  );

  test(
    'retry replaces the same receipt instead of adding a duplicate',
    () async {
      final outbox = AttendanceOutbox();
      await outbox.put(
        _receipt('same').copyWith(
          syncStatus: SyncStatus.failed,
          failureReason: 'Write refused',
        ),
      );
      await outbox.put(_receipt('same'));
      final items = await outbox.read('student-one');
      expect(items, hasLength(1));
      expect(items.single.syncStatus, SyncStatus.pending);
      expect(items.single.failureReason, isNull);
    },
  );

  test(
    'account keys and record owner filtering prevent receipt crossover',
    () async {
      final outbox = AttendanceOutbox();
      await outbox.put(_receipt('one'));
      await outbox.put(_receipt('two', uid: 'student-two'));
      expect((await outbox.read('student-one')).map((r) => r.id), ['one']);
      expect((await outbox.read('student-two')).map((r) => r.id), ['two']);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'attendance_outbox_v1_student-one',
        jsonEncode([_receipt('wrong-owner', uid: 'student-two').toLocalMap()]),
      );
      expect(await outbox.read('student-one'), isEmpty);
    },
  );

  test(
    'a corrupt account key does not poison later mutations for another account',
    () async {
      SharedPreferences.setMockInitialValues({
        'attendance_outbox_v1_student-one': 'broken-json',
      });
      final outbox = AttendanceOutbox();
      await expectLater(outbox.put(_receipt('one')), throwsFormatException);
      await outbox.put(_receipt('two', uid: 'student-two'));
      expect((await outbox.read('student-two')).single.id, 'two');
    },
  );
}
