import 'package:cloud_firestore/cloud_firestore.dart';

/// Enrollment and classroom are frozen when the faculty opens attendance.
class AttendanceSession {
  final String id, facultyId, classId, subject, roomId, date, status;
  final DateTime openedAt, closesAt;
  final List<String> enrolledStudentIds;

  const AttendanceSession({
    required this.id,
    required this.facultyId,
    required this.classId,
    required this.subject,
    required this.roomId,
    required this.date,
    required this.openedAt,
    required this.closesAt,
    required this.status,
    required this.enrolledStudentIds,
  });

  // For display only. Firestore rules enforce the server's deadline.
  bool get isOpen => status == 'open' && DateTime.now().isBefore(closesAt);

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceSession(
      id: doc.id,
      facultyId: data['facultyId'] as String,
      classId: data['classId'] as String,
      subject: data['subject'] as String,
      roomId: data['roomId'] as String,
      date: data['date'] as String,
      status: data['status'] as String,
      openedAt:
          (data['openedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      closesAt: (data['closesAt'] as Timestamp).toDate(),
      enrolledStudentIds: List<String>.from(data['enrolledStudentIds'] as List),
    );
  }
}
