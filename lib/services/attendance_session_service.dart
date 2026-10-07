import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_session_model.dart';
import '../models/schedule_model.dart';
import '../models/user_model.dart';
import 'campus_time.dart';

class AttendanceSessionService {
  final FirebaseFirestore _db;
  AttendanceSessionService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  Stream<List<AppUser>> streamStudents() => _db
      .collection('users')
      .where('role', isEqualTo: 'student')
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromFirestore).toList());

  Stream<List<String>> streamEnrollment(String facultyId, String classId) => _db
      .doc('users/$facultyId/class_schedule/$classId')
      .snapshots()
      .map(
        (doc) => List<String>.from(doc.data()?['studentIds'] as List? ?? []),
      );

  Future<void> setEnrollment({
    required String facultyId,
    required String classId,
    required List<String> studentIds,
  }) async {
    if (studentIds.length > 200) {
      throw ArgumentError('A session supports at most 200 students.');
    }
    final doc = _db.doc('users/$facultyId/class_schedule/$classId');
    await _db.runTransaction((tx) async {
      if (!(await tx.get(doc)).exists) {
        throw StateError('This class no longer exists.');
      }
      tx.update(doc, {'studentIds': studentIds.toSet().toList()..sort()});
    });
  }

  Future<String> openSession({
    required String facultyId,
    required ClassSchedule schedule,
    required List<String> studentIds,
    Duration duration = const Duration(minutes: 30),
  }) async {
    if (studentIds.isEmpty || studentIds.length > 200) {
      throw ArgumentError('Select between 1 and 200 students.');
    }
    if (duration < const Duration(minutes: 1) ||
        duration > const Duration(hours: 4)) {
      throw ArgumentError('Choose an attendance window of 1–240 minutes.');
    }
    if (schedule.roomName.trim().isEmpty || schedule.subject.trim().isEmpty) {
      throw StateError('Set the class subject and exact beacon room ID first.');
    }
    final now = DateTime.now();
    final doc = _db.collection('attendance_sessions').doc();
    // A transaction requires an online server response before claiming success.
    await _db.runTransaction((tx) async {
      final source = await tx.get(
        _db.doc('users/$facultyId/class_schedule/${schedule.id}'),
      );
      final data = source.data();
      if (data == null) throw StateError('This class no longer exists.');
      final enrolled = List<String>.from(data['studentIds'] as List? ?? []);
      if (enrolled.toSet().length != studentIds.toSet().length ||
          !enrolled.toSet().containsAll(studentIds)) {
        throw StateError('Enrollment changed. Reopen the class and try again.');
      }
      tx.set(doc, {
        'facultyId': facultyId,
        'classId': schedule.id,
        'subject': data['subject'],
        'roomId': data['roomName'],
        'date': CampusTime.dateKey(now),
        'openedAt': FieldValue.serverTimestamp(),
        'closesAt': Timestamp.fromDate(now.add(duration)),
        'status': 'open',
        'enrolledStudentIds': enrolled,
      });
    });
    return doc.id;
  }

  Future<void> closeSession({
    required String sessionId,
    required String facultyId,
  }) async {
    final doc = _db.collection('attendance_sessions').doc(sessionId);
    await _db.runTransaction((tx) async {
      final session = AttendanceSession.fromFirestore(await tx.get(doc));
      if (session.facultyId != facultyId) {
        throw StateError('This is not your session.');
      }
      tx.update(doc, {
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> correctAttendance({
    required String recordId,
    required String facultyId,
    required String status,
    required String reason,
  }) async {
    final explanation = reason.trim();
    if (!['present', 'late', 'excused', 'absent'].contains(status)) {
      throw ArgumentError('Invalid attendance status.');
    }
    if (explanation.length < 10 || explanation.length > 500) {
      throw ArgumentError('Provide a reason of 10–500 characters.');
    }
    final record = _db.collection('attendance').doc(recordId);
    final audit = record.collection('corrections').doc();
    await _db.runTransaction((tx) async {
      final data = (await tx.get(record)).data();
      if (data == null || data['facultyId'] != facultyId) {
        throw StateError('Record unavailable for this faculty account.');
      }
      if (data['attendanceStatus'] == status) {
        throw StateError('Choose a different status.');
      }
      tx.set(audit, {
        'facultyId': facultyId,
        'fromStatus': data['attendanceStatus'],
        'toStatus': status,
        'reason': explanation,
        'at': FieldValue.serverTimestamp(),
      });
      tx.update(record, {
        'attendanceStatus': status,
        'lastCorrectionId': audit.id,
        'correctedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
