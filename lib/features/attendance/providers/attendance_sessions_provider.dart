import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_mark_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_session_service.dart';
import '../../../core/campus_time.dart';
import '../../../shared/providers/auth_provider.dart';

final sessionServiceProvider = Provider((ref) => AttendanceSessionService());

final studentSessionsProvider = StreamProvider<List<AttendanceSession>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('attendance_sessions')
      .where('enrolledStudentIds', arrayContains: uid)
      .where('date', isEqualTo: CampusTime.dateKey(DateTime.now()))
      .snapshots()
      .map(
        (s) =>
            s.docs.map(AttendanceSession.fromFirestore).toList()
              ..sort((a, b) => b.openedAt.compareTo(a.openedAt)),
      );
});

final facultySessionsProvider = StreamProvider<List<AttendanceSession>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('attendance_sessions')
      .where('facultyId', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(AttendanceSession.fromFirestore).toList()
              ..sort((a, b) => b.openedAt.compareTo(a.openedAt)),
      );
});

/// Own session marks (faculty-issued statuses for students without receipts).
final sessionMarksProvider = StreamProvider.family<List<AttendanceMark>,
    ({String facultyId, String sessionId})>((ref, key) {
  if (key.facultyId.isEmpty) return Stream.value([]);
  return ref
      .read(sessionServiceProvider)
      .streamMarks(facultyId: key.facultyId, sessionId: key.sessionId);
});

final sessionRecordsProvider =
    StreamProvider.family<List<AttendanceRecord>, String>((ref, id) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection('attendance')
          .where('facultyId', isEqualTo: uid)
          .where('sessionId', isEqualTo: id)
          .snapshots(includeMetadataChanges: true)
          .map((s) => s.docs.map(AttendanceRecord.fromFirestore).toList());
    });
