import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_mark_model.dart';
import '../models/attendance_session_model.dart';
import '../models/schedule_model.dart';
import '../../../core/user_model.dart';
import '../../../core/campus_time.dart';

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

  /// Creates or returns the short code students use to enroll themselves.
  /// The public `class_codes/{code}` document is the only lookup students can
  /// perform, so the full faculty schedule and enrollment stay private.
  Future<String> ensureJoinCode({
    required String facultyId,
    required String classId,
  }) async {
    final doc = _db.doc('users/$facultyId/class_schedule/$classId');
    final schedule = await doc.get(const GetOptions(source: Source.server));
    if (!schedule.exists) throw StateError('This class no longer exists.');
    final data = schedule.data()!;
    final existing = data['joinCode'] as String?;
    if (existing != null && existing.isNotEmpty) {
      await _writeCodeDoc(existing, facultyId, classId, data);
      return existing;
    }
    var code = JoinCode.generate();
    for (var attempt = 0; attempt < 5; attempt++) {
      final taken = await _db
          .collection('class_codes')
          .doc(code)
          .get(const GetOptions(source: Source.server));
      if (!taken.exists) break;
      code = JoinCode.generate();
    }
    await doc.update({'joinCode': code});
    await _writeCodeDoc(code, facultyId, classId, data);
    return code;
  }

  Future<void> _writeCodeDoc(
    String code,
    String facultyId,
    String classId,
    Map<String, dynamic> data,
  ) => _db.collection('class_codes').doc(code).set({
    'facultyId': facultyId,
    'classId': classId,
    'subject': data['subject'] ?? '',
    'roomName': data['roomName'] ?? '',
    'dayOfWeek': data['dayOfWeek'] ?? '',
    'startTime': data['startTime'] ?? '',
    'endTime': data['endTime'] ?? '',
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// Students join by writing a member document under the code they know.
  /// Firestore rules allow only their own member document, so a student can
  /// never edit another student's enrollment or the faculty schedule.
  Future<ClassSchedule> enrollWithCode({
    required String studentId,
    required String code,
  }) async {
    final normalized = JoinCode.normalize(code);
    if (normalized.length != 6) {
      throw StateError('Enter the 6-character class code.');
    }
    final codeRef = _db.collection('class_codes').doc(normalized);
    final codeDoc = await codeRef.get(const GetOptions(source: Source.server));
    final data = codeDoc.data();
    if (!codeDoc.exists || data == null) {
      throw StateError(
        'No class uses that code. Ask your teacher to check it.',
      );
    }
    final member = codeRef.collection('members').doc(studentId);
    final alreadyJoined = (await member.get(
      const GetOptions(source: Source.server),
    )).exists;
    // Re-entering a code is harmless: return the class so the student sees
    // confirmation instead of an error.
    if (!alreadyJoined) {
      await member.set({
        'studentId': studentId,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    }
    return ClassSchedule(
      id: data['classId'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as String? ?? '',
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
      joinCode: normalized,
    );
  }

  /// UIDs added through a class code but not yet merged into the schedule.
  Future<List<String>> joinCodeMembers(String code) async {
    if (code.isEmpty) return [];
    final snapshot = await _db
        .collection('class_codes')
        .doc(code)
        .collection('members')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map((doc) => doc.id).toList();
  }

  Future<String> openSession({
    required String facultyId,
    required ClassSchedule schedule,
    required List<String> studentIds,
    Duration duration = const Duration(minutes: 30),
    String? joinCode,
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
        // Publishes the class code students joined with, so a student who
        // joins after the window opened can still find and attend this
        // session instead of being locked out by the frozen roster.
        if (joinCode != null && joinCode.isNotEmpty) 'joinCode': joinCode,
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

  /// Faculty-issued attendance for an enrolled student who has no receipt.
  /// Written into the separate `attendance_marks` collection so real scan
  /// evidence in `attendance` is never rewritten or shadowed.
  Future<void> markStudent({
    required AttendanceSession session,
    required String facultyId,
    required String studentId,
    required String status,
    required String reason,
    String? studentName,
  }) async {
    if (session.facultyId != facultyId) {
      throw StateError('This is not your session.');
    }
    if (session.status != 'closed') {
      throw StateError('Close attendance before issuing marks.');
    }
    if (!session.enrolledStudentIds.contains(studentId)) {
      throw StateError('That student is not enrolled in this session.');
    }
    if (!['absent', 'late', 'excused'].contains(status)) {
      throw ArgumentError('Marks support absent, late, or excused.');
    }
    final explanation = reason.trim();
    if (explanation.length < 10 || explanation.length > 500) {
      throw ArgumentError('Provide a reason of 10–500 characters.');
    }
    final name = studentName?.trim() ?? '';
    await _db
        .collection('attendance_marks')
        .doc('${session.id}_$studentId')
        .set({
      'facultyId': facultyId,
      'studentId': studentId,
      'sessionId': session.id,
      'subject': session.subject,
      'attendanceStatus': status,
      'reason': explanation,
      'markedAt': FieldValue.serverTimestamp(),
      if (name.isNotEmpty) 'studentName': name,
    });
  }

  Stream<List<AttendanceMark>> streamMarks({
    required String facultyId,
    required String sessionId,
  }) =>
      _db
          .collection('attendance_marks')
          .where('facultyId', isEqualTo: facultyId)
          .where('sessionId', isEqualTo: sessionId)
          .snapshots()
          .map(
            (s) => s.docs.map(AttendanceMark.fromFirestore).toList(),
          );
}
