import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:findmoser_app/models/attendance_model.dart';
import 'package:findmoser_app/models/schedule_model.dart';
import 'package:findmoser_app/services/attendance_outbox.dart';
import 'package:findmoser_app/services/attendance_service.dart';
import 'package:findmoser_app/services/attendance_session_service.dart';
import 'package:findmoser_app/services/campus_time.dart';

const _uid = 'student-one';
const _phone = '0123456789abcdef';
const _session = 'session-one';
final _id = AttendanceService.recordId(_session, _uid);

Future<void> _seed(FirebaseFirestore db) async {
  await db.collection('users').doc(_uid).set({
    'role': 'student',
    'deviceId': _phone,
    'displayName': 'Verified Name',
  });
  await db.collection('device_bindings').doc(_phone).set({'uid': _uid});
  await db.collection('attendance_sessions').doc(_session).set({
    'facultyId': 'faculty-one',
    'classId': 'class-one',
    'subject': 'Programming',
    'roomId': 'Room305',
    'date': CampusTime.dateKey(DateTime.now()),
    'openedAt': Timestamp.now(),
    'closesAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(minutes: 20)),
    ),
    'status': 'open',
    'enrolledStudentIds': [_uid],
  });
}

Future<String> _record(
  AttendanceService service, {
  String roomId = 'Room305',
  String beaconId = 'FindMoSer_Room305',
  int rssi = -64,
  int dwellSeconds = 15,
}) => service.recordAttendance(
  sessionId: _session,
  studentId: _uid,
  studentName: 'Forged client name',
  facultyId: 'faculty-one',
  classId: 'class-one',
  subject: 'Forged subject',
  beaconId: beaconId,
  roomId: roomId,
  zoneName: 'Forged zone',
  rssi: rssi,
  dwellSeconds: dwellSeconds,
  deviceId: _phone,
);

AttendanceRecord _receipt({SyncStatus status = SyncStatus.pending}) =>
    AttendanceRecord(
      id: _id,
      studentId: _uid,
      studentName: 'Verified Name',
      facultyId: 'faculty-one',
      classId: 'class-one',
      sessionId: _session,
      subject: 'Programming',
      beaconId: 'FindMoSer_Room305',
      roomId: 'Room305',
      zoneName: 'Room305',
      rssi: -64,
      dwellSeconds: 15,
      deviceId: _phone,
      localTimestamp: DateTime.now(),
      date: CampusTime.dateKey(DateTime.now()),
      syncStatus: status,
    );

class _ControlledFirestore extends Fake implements FirebaseFirestore {
  final FakeFirebaseFirestore data;
  Future<void> Function(
    DocumentReference<Map<String, dynamic>>,
    Map<String, dynamic>,
    SetOptions?,
  )?
  write;
  int writes = 0;
  _ControlledFirestore(this.data);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      path == 'attendance'
      ? _Collection(this, data.collection(path))
      : data.collection(path);
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final _ControlledFirestore owner;
  final CollectionReference<Map<String, dynamic>> target;
  _Collection(this.owner, this.target);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(owner, target.doc(path));
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final _ControlledFirestore owner;
  final DocumentReference<Map<String, dynamic>> target;
  _Document(this.owner, this.target);
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([GetOptions? options]) =>
      target.get(options);
  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    owner.writes++;
    if (owner.write != null) {
      await owner.write!(target, data, options);
    } else {
      await target.set(data, options);
    }
  }
}

class _FailingCleanupOutbox extends AttendanceOutbox {
  @override
  Future<void> remove(String uid, String id) async =>
      throw StateError('Local storage unavailable');
}

class _UnreadableOutbox extends AttendanceOutbox {
  @override
  Future<List<AttendanceRecord>> read(String uid) async =>
      throw const FormatException('Damaged local receipt data');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'confirmed attendance uses verified identity, classroom and session fields',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db);
      final outbox = AttendanceOutbox();
      final service = AttendanceService(
        db: db,
        outbox: outbox,
        currentUid: () => _uid,
      );
      expect(await _record(service), _id);
      final record = AttendanceRecord.fromFirestore(
        await db.collection('attendance').doc(_id).get(),
      );
      expect(record.studentName, 'Verified Name');
      expect(record.subject, 'Programming');
      expect(record.zoneName, 'Room305');
      expect(record.isSynced, true);
      expect(await outbox.read(_uid), isEmpty);
      await expectLater(_record(service), throwsStateError);
      expect((await db.collection('attendance').get()).docs, hasLength(1));
    },
  );

  test(
    'preflight rejects wrong reverse ownership, non-members and closed sessions',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db);
      final service = AttendanceService(db: db, currentUid: () => _uid);
      Future<void> expectRejected() async => expectLater(
        service.preflightSession(
          sessionId: _session,
          studentId: _uid,
          deviceId: _phone,
        ),
        throwsStateError,
      );
      await db.collection('device_bindings').doc(_phone).update({
        'uid': 'someone-else',
      });
      await expectRejected();
      await db.collection('device_bindings').doc(_phone).update({'uid': _uid});
      await db.collection('attendance_sessions').doc(_session).update({
        'enrolledStudentIds': ['other'],
      });
      await expectRejected();
      await db.collection('attendance_sessions').doc(_session).update({
        'enrolledStudentIds': [_uid],
        'status': 'closed',
      });
      await expectRejected();
      expect((await db.collection('attendance').get()).docs, isEmpty);
    },
  );

  test(
    'wrong room, wrong beacon, weak signal and incomplete dwell never write attendance',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db);
      final outbox = AttendanceOutbox();
      final service = AttendanceService(
        db: db,
        outbox: outbox,
        currentUid: () => _uid,
      );
      await expectLater(_record(service, roomId: 'Room306'), throwsStateError);
      await expectLater(
        _record(service, beaconId: 'FindMoSer_Room306'),
        throwsStateError,
      );
      await expectLater(_record(service, rssi: -71), throwsStateError);
      await expectLater(_record(service, dwellSeconds: 14), throwsStateError);
      expect((await db.collection('attendance').get()).docs, isEmpty);
      expect(await outbox.read(_uid), isEmpty);
    },
  );

  test(
    'server rejection remains visible after a service restart and is not retried automatically',
    () async {
      final data = FakeFirebaseFirestore();
      await _seed(data);
      final db = _ControlledFirestore(data)
        ..write = (_, __, ___) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        };
      final outbox = AttendanceOutbox();
      await expectLater(
        _record(
          AttendanceService(db: db, outbox: outbox, currentUid: () => _uid),
        ),
        throwsA(isA<FirebaseException>()),
      );
      final restored = AttendanceOutbox();
      expect((await restored.read(_uid)).single.syncStatus, SyncStatus.failed);
      final restarted = AttendanceService(
        db: data,
        outbox: restored,
        currentUid: () => _uid,
      );
      final records = await restarted
          .streamStudentAttendanceToday(_uid)
          .firstWhere((items) => items.any((r) => r.id == _id))
          .timeout(const Duration(seconds: 2));
      expect(records.single.syncStatus, SyncStatus.failed);
      expect(records.single.failureReason, contains('permission-denied'));
      expect((await data.collection('attendance').get()).docs, isEmpty);
    },
  );

  test(
    'recovery removes a stale receipt without overwriting a confirmed faculty correction',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db);
      final saved = _receipt().toFirestore()..['attendanceStatus'] = 'late';
      await db.collection('attendance').doc(_id).set(saved);
      final outbox = AttendanceOutbox();
      await outbox.put(_receipt());
      final removed = outbox.changes.firstWhere((uid) => uid == _uid);
      final service = AttendanceService(
        db: db,
        outbox: outbox,
        currentUid: () => _uid,
      );
      final subscription = service
          .streamStudentAttendanceToday(_uid)
          .listen((_) {});
      await removed.timeout(const Duration(seconds: 2));
      await subscription.cancel();
      expect(await outbox.read(_uid), isEmpty);
      expect(
        (await db.collection('attendance').doc(_id).get())
            .data()?['attendanceStatus'],
        'late',
      );
    },
  );

  test(
    'local cleanup failure cannot turn acknowledged attendance into a failed submission',
    () async {
      final db = FakeFirebaseFirestore();
      await _seed(db);
      final outbox = _FailingCleanupOutbox();
      final service = AttendanceService(
        db: db,
        outbox: outbox,
        currentUid: () => _uid,
      );
      expect(await _record(service), _id);
      expect(
        AttendanceRecord.fromFirestore(
          await db.collection('attendance').doc(_id).get(),
        ).isSynced,
        true,
      );
      expect(
        (await outbox.read(_uid)).single.syncStatus,
        isNot(SyncStatus.failed),
      );
    },
  );

  test(
    'transport interruption retains a pending receipt for reconnection recovery',
    () async {
      final data = FakeFirebaseFirestore();
      await _seed(data);
      final db = _ControlledFirestore(data)
        ..write = (_, __, ___) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        };
      final outbox = AttendanceOutbox();
      final service = AttendanceService(
        db: db,
        outbox: outbox,
        currentUid: () => _uid,
      );
      await expectLater(
        _record(service),
        throwsA(isA<AttendancePendingException>()),
      );
      expect((await outbox.read(_uid)).single.syncStatus, SyncStatus.pending);

      // A later app session with connectivity reconciles the persisted receipt.
      final restored = AttendanceOutbox();
      final removed = restored.changes.firstWhere((uid) => uid == _uid);
      final restarted = AttendanceService(
        db: data,
        outbox: restored,
        currentUid: () => _uid,
      );
      final subscription = restarted
          .streamStudentAttendanceToday(_uid)
          .listen((_) {});
      await removed.timeout(const Duration(seconds: 2));
      await subscription.cancel();
      expect(await restored.read(_uid), isEmpty);
      expect(
        AttendanceRecord.fromFirestore(
          await data.collection('attendance').doc(_id).get(),
        ).isSynced,
        true,
      );
    },
  );

  test('in-flight deduplication does not bypass an account change', () async {
    final data = FakeFirebaseFirestore();
    await _seed(data);
    final entered = Completer<void>();
    final release = Completer<void>();
    final db = _ControlledFirestore(data)
      ..write = (ref, value, options) async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
        await ref.set(value, options);
      };
    var activeUid = _uid;
    final service = AttendanceService(db: db, currentUid: () => activeUid);
    final first = _record(service);
    await entered.future.timeout(const Duration(seconds: 2));
    activeUid = 'different-student';
    final second = expectLater(_record(service), throwsStateError);
    release.complete();
    await first;
    await second;
    expect(db.writes, 1);
  });

  test('CSV escapes formulas and quotes while omitting pending receipts', () {
    final service = AttendanceService(
      db: FakeFirebaseFirestore(),
      currentUid: () => _uid,
    );
    expect(AttendanceService.csvCell(' =SUM(A1:A2)'), '"\' =SUM(A1:A2)"');
    expect(AttendanceService.csvCell('A, "B"\nC'), '"A, ""B""\nC"');
    expect(AttendanceService.csvCell(-64), '"-64"');
    final csv = service.generateCsv([
      _receipt(),
      _receipt().copyWith(
        syncStatus: SyncStatus.synced,
        serverTimestamp: DateTime.utc(2026, 10, 8, 2),
      ),
    ]);
    expect(csv.split('\r\n').where((row) => row.isNotEmpty), hasLength(2));
    expect(csv, contains('2026-10-08T02:00:00.000Z'));
  });

  test('unreadable local receipts surface through the stream without an uncaught recovery error', () async {
    final service = AttendanceService(
      db: FakeFirebaseFirestore(),
      outbox: _UnreadableOutbox(),
      currentUid: () => _uid,
    );
    final streamErrors = <Object>[];
    final uncaught = <Object>[];
    await runZonedGuarded(() async {
      final subscription = service.streamStudentAttendanceToday(_uid).listen(
        (_) {},
        onError: (Object error) => streamErrors.add(error),
      );
      // Drain initial snapshot/recovery microtasks before cancelling the stream.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
    }, (error, _) => uncaught.add(error));
    expect(streamErrors, isNotEmpty);
    expect(streamErrors.every((error) => error is FormatException), true);
    expect(uncaught, isEmpty);
  });

  group('faculty sessions and corrections', () {
    const schedule = ClassSchedule(
      id: 'class-one',
      dayOfWeek: 'Thursday',
      startTime: '09:00',
      endTime: '10:00',
      roomName: 'Room305',
      subject: 'Programming',
    );

    test(
      'opening freezes current enrollment and rejects a stale enrollment selection',
      () async {
        final db = FakeFirebaseFirestore();
        final ref = db.doc('users/faculty-one/class_schedule/class-one');
        await ref.set(schedule.toFirestore());
        final service = AttendanceSessionService(db: db);
        await service.setEnrollment(
          facultyId: 'faculty-one',
          classId: 'class-one',
          studentIds: ['b', 'a', 'a'],
        );
        final id = await service.openSession(
          facultyId: 'faculty-one',
          schedule: schedule,
          studentIds: ['a', 'b'],
        );
        await service.setEnrollment(
          facultyId: 'faculty-one',
          classId: 'class-one',
          studentIds: ['b'],
        );
        expect(
          (await db.collection('attendance_sessions').doc(id).get())
              .data()?['enrolledStudentIds'],
          ['a', 'b'],
        );
        await expectLater(
          service.openSession(
            facultyId: 'faculty-one',
            schedule: schedule,
            studentIds: ['a', 'b'],
          ),
          throwsStateError,
        );
        await expectLater(
          service.closeSession(sessionId: id, facultyId: 'wrong-faculty'),
          throwsStateError,
        );
        await service.closeSession(sessionId: id, facultyId: 'faculty-one');
        expect(
          (await db.collection('attendance_sessions').doc(id).get())
              .data()?['status'],
          'closed',
        );
      },
    );

    test(
      'correction keeps scan evidence and atomically records who changed the status and why',
      () async {
        final db = FakeFirebaseFirestore();
        await db
            .collection('attendance')
            .doc(_id)
            .set(_receipt().toFirestore());
        final service = AttendanceSessionService(db: db);
        await expectLater(
          service.correctAttendance(
            recordId: _id,
            facultyId: 'wrong-faculty',
            status: 'late',
            reason: 'Approved correction after review.',
          ),
          throwsStateError,
        );
        await expectLater(
          service.correctAttendance(
            recordId: _id,
            facultyId: 'faculty-one',
            status: 'late',
            reason: 'short',
          ),
          throwsArgumentError,
        );
        await service.correctAttendance(
          recordId: _id,
          facultyId: 'faculty-one',
          status: 'late',
          reason: '  Approved correction after review.  ',
        );
        final record = (await db.collection('attendance').doc(_id).get())
            .data()!;
        final audit =
            (await db
                    .collection('attendance')
                    .doc(_id)
                    .collection('corrections')
                    .get())
                .docs
                .single;
        expect(record['attendanceStatus'], 'late');
        expect(record['rssi'], -64);
        expect(record['dwellSeconds'], 15);
        expect(record['lastCorrectionId'], audit.id);
        expect(audit.data()['fromStatus'], 'present');
        expect(audit.data()['toStatus'], 'late');
        expect(audit.data()['facultyId'], 'faculty-one');
        expect(audit.data()['reason'], 'Approved correction after review.');
        await expectLater(
          service.correctAttendance(
            recordId: _id,
            facultyId: 'faculty-one',
            status: 'late',
            reason: 'Repeat same status correction.',
          ),
          throwsStateError,
        );
      },
    );
  });
}
