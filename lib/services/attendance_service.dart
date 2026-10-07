import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../config/app_constants.dart';
import '../models/attendance_model.dart';
import '../models/attendance_session_model.dart';
import 'attendance_outbox.dart';
import 'campus_time.dart';

class AttendancePendingException implements Exception {
  const AttendancePendingException();
  @override
  String toString() =>
      'Upload is still pending. Reconnect and check your attendance receipts.';
}

class _ValidatedSession {
  final AttendanceSession session;
  final String deviceId, studentName;
  final DateTime checkedAt;
  _ValidatedSession(this.session, this.deviceId, this.studentName)
    : checkedAt = DateTime.now();
}

/// Server-authorized sessions; durable local receipts never imply acceptance.
class AttendanceService {
  final FirebaseFirestore _db;
  final AttendanceOutbox _outbox;
  final String? Function() _currentUid;
  final _validated = <String, _ValidatedSession>{};
  final _writes = <String, Future<String>>{};
  final _recovering = <String>{};

  AttendanceService({
    FirebaseFirestore? db,
    AttendanceOutbox? outbox,
    String? Function()? currentUid,
  }) : _db = db ?? FirebaseFirestore.instance,
       _outbox = outbox ?? AttendanceOutbox(),
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  static String recordId(String sessionId, String studentId) =>
      '${sessionId}_$studentId';

  Future<AttendanceSession> preflightSession({
    required String sessionId,
    required String studentId,
    required String deviceId,
  }) async {
    if (_currentUid() != studentId || sessionId.isEmpty) {
      throw StateError('Sign in to check attendance.');
    }
    const server = GetOptions(source: Source.server);
    final profile = (await _db.collection('users').doc(studentId).get(server))
        .data();
    final binding =
        (await _db.collection('device_bindings').doc(deviceId).get(server))
            .data();
    if (profile?['role'] != 'student' ||
        profile?['deviceId'] != deviceId ||
        binding?['uid'] != studentId) {
      throw StateError(
        'This account is not registered to this phone. Request a device change from the project team.',
      );
    }
    final doc = await _db
        .collection('attendance_sessions')
        .doc(sessionId)
        .get(server);
    if (!doc.exists) {
      throw StateError('This attendance session no longer exists.');
    }
    final session = AttendanceSession.fromFirestore(doc);
    if (!session.isOpen || !session.enrolledStudentIds.contains(studentId)) {
      throw StateError(
        'Attendance is closed or you are not enrolled in this session.',
      );
    }
    final existing = await _db
        .collection('attendance')
        .doc(recordId(sessionId, studentId))
        .get(server);
    if (existing.exists) {
      throw StateError(
        'Your attendance is already confirmed for this session.',
      );
    }
    _validated[recordId(sessionId, studentId)] = _ValidatedSession(
      session,
      deviceId,
      profile!['displayName'] as String,
    );
    return session;
  }

  Future<String> recordAttendance({
    required String sessionId,
    required String studentId,
    required String studentName,
    required String facultyId,
    required String classId,
    required String subject,
    required String beaconId,
    required String roomId,
    required String zoneName,
    required int rssi,
    required int dwellSeconds,
    required String deviceId,
  }) async {
    final id = recordId(sessionId, studentId);
    if (_currentUid() != studentId) {
      throw StateError('Your sign-in changed. Start a new scan.');
    }
    if (_writes.containsKey(id)) return _writes[id]!;
    var context = _validated[id];
    if (context == null) {
      await preflightSession(
        sessionId: sessionId,
        studentId: studentId,
        deviceId: deviceId,
      );
      context = _validated[id]!;
    }
    final session = context.session;
    if (DateTime.now().difference(context.checkedAt) >
            const Duration(minutes: 2) ||
        !session.isOpen) {
      throw StateError('Session verification expired. Start a new scan.');
    }
    if (context.deviceId != deviceId ||
        roomId != session.roomId ||
        beaconId != '${AppConstants.blePrefix}${session.roomId}' ||
        facultyId != session.facultyId ||
        classId != session.classId ||
        rssi < AppConstants.attendanceRssiThreshold ||
        rssi > 0 ||
        dwellSeconds < AppConstants.attendanceDwellSeconds ||
        dwellSeconds > 120) {
      throw StateError(
        'The scan does not match the enrolled classroom or proximity requirement.',
      );
    }
    final record = AttendanceRecord(
      id: id,
      sessionId: sessionId,
      studentId: studentId,
      studentName: context.studentName,
      facultyId: session.facultyId,
      classId: session.classId,
      subject: session.subject,
      beaconId: beaconId,
      roomId: session.roomId,
      zoneName: session.roomId,
      rssi: rssi,
      dwellSeconds: dwellSeconds,
      deviceId: deviceId,
      localTimestamp: DateTime.now(),
      date: session.date,
    );
    await _outbox.put(record);
    return _submit(record);
  }

  Future<String> _submit(AttendanceRecord record) {
    final inFlight = _writes[record.id];
    if (inFlight != null) return inFlight;
    final future = _send(record);
    _writes[record.id] = future;
    return future;
  }

  Future<String> _send(AttendanceRecord record) async {
    try {
      if (_currentUid() != record.studentId) {
        throw StateError('Sign in to the account that submitted this record.');
      }
      try {
        // Resolves only after server acknowledgement. Rules allow create only.
        await _db
            .collection('attendance')
            .doc(record.id)
            .set(record.toFirestore());
      } catch (error) {
        // Firestore may have accepted a persisted write before an outbox retry.
        // Read confirmation without rewriting the original scan evidence.
        if (_currentUid() == record.studentId) {
          try {
            final existing = await _db
                .collection('attendance')
                .doc(record.id)
                .get(const GetOptions(source: Source.server))
                .timeout(const Duration(seconds: 10));
            if (existing.exists &&
                AttendanceRecord.fromFirestore(existing).isSynced) {
              await _removeReceipt(record);
              return record.id;
            }
          } catch (_) {
            /* Preserve the original submission outcome. */
          }
        }
        final transient =
            error is FirebaseException &&
            [
              'unavailable',
              'deadline-exceeded',
              'network-request-failed',
            ].contains(error.code);
        try {
          await _outbox.put(
            transient
                ? record
                : record.copyWith(
                    syncStatus: SyncStatus.failed,
                    failureReason:
                        'Not confirmed: ${error.toString().replaceFirst('Bad state: ', '')}',
                  ),
          );
        } catch (localError) {
          debugPrint('Could not update local attendance receipt: $localError');
        }
        if (transient) throw const AttendancePendingException();
        rethrow;
      }
      // Local cleanup must never turn an acknowledged server write into a failure.
      await _removeReceipt(record);
      return record.id;
    } finally {
      _writes.remove(record.id);
      _validated.remove(record.id);
    }
  }

  Future<void> _removeReceipt(AttendanceRecord record) async {
    try {
      await _outbox.remove(record.studentId, record.id);
    } catch (error) {
      // A later server snapshot/restart reconciles this stale local receipt.
      debugPrint(
        'Attendance confirmed; local receipt cleanup deferred: $error',
      );
    }
  }

  /// Restart recovery retries pending receipts only; rejected evidence requires
  /// a fresh scan. Rules recheck the current session and device registration.
  Future<void> _recover(String uid) async {
    if (!_recovering.add(uid)) return;
    try {
      for (final item in await _outbox.read(uid)) {
        if (_currentUid() != uid) return;
        if (item.syncStatus != SyncStatus.pending ||
            _writes.containsKey(item.id)) {
          continue;
        }
        unawaited(_recoverOne(item));
      }
    } finally {
      _recovering.remove(uid);
    }
  }

  Future<void> _recoverOne(AttendanceRecord item) async {
    try {
      final server = await _db
          .collection('attendance')
          .doc(item.id)
          .get(const GetOptions(source: Source.server));
      if (server.exists && AttendanceRecord.fromFirestore(server).isSynced) {
        await _outbox.remove(item.studentId, item.id);
      } else if (_currentUid() == item.studentId) {
        await _submit(item);
      }
    } on FirebaseException catch (e) {
      if (![
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      ].contains(e.code)) {
        await _outbox.put(
          item.copyWith(
            syncStatus: SyncStatus.failed,
            failureReason: 'Not confirmed: ${e.message ?? e.code}',
          ),
        );
      }
    } catch (_) {
      /* Pending remains visible if local recovery cannot finish. */
    }
  }

  Stream<AttendanceRecord?> streamRecord(String id) => _db
      .collection('attendance')
      .doc(id)
      .snapshots(includeMetadataChanges: true)
      .map((doc) => doc.exists ? AttendanceRecord.fromFirestore(doc) : null);

  Stream<List<AttendanceRecord>> streamStudentAttendanceToday(
    String studentId,
  ) {
    final date = CampusTime.dateKey(DateTime.now());
    late StreamController<List<AttendanceRecord>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSubscription;
    StreamSubscription<String>? localSubscription;
    var remote = <AttendanceRecord>[];
    Future<void> emit() async {
      try {
        final local = await _outbox.read(studentId);
        final records = {
          for (final r in local.where((r) => r.date == date)) r.id: r,
        };
        for (final record in remote) {
          // Confirmed server evidence wins; failed local receipts survive rollback.
          if (record.isSynced ||
              records[record.id]?.syncStatus != SyncStatus.failed) {
            records[record.id] = record;
          }
        }
        if (!controller.isClosed) {
          controller.add(
            records.values.toList()
              ..sort((a, b) => b.localTimestamp.compareTo(a.localTimestamp)),
          );
        }
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      }
    }

    controller = StreamController<List<AttendanceRecord>>(
      onListen: () {
        localSubscription = _outbox.changes
            .where((uid) => uid == studentId)
            .listen((_) => unawaited(emit()));
        remoteSubscription = _query('studentId', studentId, date)
            .snapshots(includeMetadataChanges: true)
            .listen((snapshot) {
              remote = snapshot.docs
                  .map(AttendanceRecord.fromFirestore)
                  .toList();
              unawaited(emit());
              if (!snapshot.metadata.isFromCache) {
                unawaited(_recover(studentId));
              }
            }, onError: controller.addError);
        unawaited(emit());
        unawaited(_recover(studentId));
      },
      onCancel: () async {
        await localSubscription?.cancel();
        await remoteSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<bool> hasAttendanceToday({
    required String studentId,
    required String classId,
  }) async =>
      (await _query('studentId', studentId, CampusTime.dateKey(DateTime.now()))
              .where('classId', isEqualTo: classId)
              .limit(1)
              .get(const GetOptions(source: Source.server)))
          .docs
          .isNotEmpty;

  Future<List<AttendanceRecord>> getStudentAttendanceToday(String studentId) =>
      _get(_query('studentId', studentId, CampusTime.dateKey(DateTime.now())));
  Future<List<AttendanceRecord>> getClassAttendance({
    required String facultyId,
    required String classId,
    required String date,
  }) => _get(
    _query('facultyId', facultyId, date).where('classId', isEqualTo: classId),
  );
  Future<List<AttendanceRecord>> getFacultyAttendanceByDate({
    required String facultyId,
    required String date,
  }) => _get(_query('facultyId', facultyId, date));
  Stream<List<AttendanceRecord>> streamClassAttendanceToday({
    required String facultyId,
  }) => _query('facultyId', facultyId, CampusTime.dateKey(DateTime.now()))
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs.map(AttendanceRecord.fromFirestore).toList());

  Future<List<AttendanceRecord>> getAttendanceForExport({
    required String facultyId,
    required String classId,
    String? sessionId,
    String? fromDate,
    String? toDate,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('attendance')
        .where('facultyId', isEqualTo: facultyId)
        .where('classId', isEqualTo: classId);
    if (sessionId != null) {
      query = query.where('sessionId', isEqualTo: sessionId);
    }
    // Client filtering after an owner-scoped server query avoids a separate
    // inequality index for each export range and never exports stale cache.
    final records = await _get(query);
    return records
        .where(
          (r) =>
              r.isSynced &&
              (fromDate == null || r.date.compareTo(fromDate) >= 0) &&
              (toDate == null || r.date.compareTo(toDate) <= 0),
        )
        .toList()
      ..sort((a, b) => a.localTimestamp.compareTo(b.localTimestamp));
  }

  String generateCsv(List<AttendanceRecord> records) {
    final rows = <List<Object>>[
      [
        'Date (Cebu)',
        'Session ID',
        'Student ID',
        'Student Name',
        'Subject',
        'Room',
        'Server time (UTC)',
        'Phone time (UTC)',
        'Signal (dBm)',
        'Dwell (s)',
        'Attendance status',
      ],
      for (final r in records.where((r) => r.isSynced))
        [
          r.date,
          r.sessionId,
          r.studentId,
          r.studentName,
          r.subject,
          r.roomId,
          r.serverTimestamp!.toUtc().toIso8601String(),
          r.localTimestamp.toUtc().toIso8601String(),
          r.rssi,
          r.dwellSeconds,
          r.attendanceStatus,
        ],
    ];
    return '${rows.map((row) => row.map(csvCell).join(',')).join('\r\n')}\r\n';
  }

  static String csvCell(Object value) {
    var text = value.toString();
    if (value is String && RegExp(r'^\s*[=+@\-\t\r\n]').hasMatch(text)) {
      text = "'$text";
    }
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<bool> isDeviceBound({
    required String deviceId,
    required String currentUid,
  }) async {
    final doc = await _db
        .collection('device_bindings')
        .doc(deviceId)
        .get(const GetOptions(source: Source.server));
    return doc.exists && doc.data()?['uid'] != currentUid;
  }

  Query<Map<String, dynamic>> _query(String field, String value, String date) =>
      _db
          .collection('attendance')
          .where(field, isEqualTo: value)
          .where('date', isEqualTo: date);
  Future<List<AttendanceRecord>> _get(
    Query<Map<String, dynamic>> query,
  ) async => (await query.get(
    const GetOptions(source: Source.server),
  )).docs.map(AttendanceRecord.fromFirestore).toList();
}
