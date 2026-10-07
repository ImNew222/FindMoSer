import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../models/attendance_session_model.dart';
import '../services/attendance_session_service.dart';
import '../services/campus_time.dart';
import 'auth_provider.dart';

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
      .where('date', isEqualTo: CampusTime.dateKey(DateTime.now()))
      .snapshots()
      .map(
        (s) =>
            s.docs.map(AttendanceSession.fromFirestore).toList()
              ..sort((a, b) => b.openedAt.compareTo(a.openedAt)),
      );
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
