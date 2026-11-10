import 'package:cloud_firestore/cloud_firestore.dart';

/// Faculty-issued attendance decision for an enrolled student who never
/// submitted a receipt. Firestore rules allow create-only, owning-faculty
/// writes on closed sessions, and the document ID embeds one receipt slot:
/// {sessionId}_{studentId}.
class AttendanceMark {
  final String id, facultyId, studentId, sessionId, subject, status, reason;
  final DateTime markedAt;
  final String? studentName;

  const AttendanceMark({
    required this.id,
    required this.facultyId,
    required this.studentId,
    required this.sessionId,
    required this.subject,
    required this.status,
    required this.reason,
    required this.markedAt,
    this.studentName,
  });

  factory AttendanceMark.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceMark(
      id: doc.id,
      facultyId: data['facultyId'] as String,
      studentId: data['studentId'] as String,
      sessionId: data['sessionId'] as String,
      subject: data['subject'] as String,
      status: data['attendanceStatus'] as String,
      reason: data['reason'] as String,
      markedAt: (data['markedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      studentName: data['studentName'] as String?,
    );
  }
}
