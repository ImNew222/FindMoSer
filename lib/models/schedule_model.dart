import 'package:cloud_firestore/cloud_firestore.dart';

class ClassSchedule {
  final String id;
  final String dayOfWeek; // e.g. "Monday"
  final String startTime; // e.g. "09:00"
  final String endTime; // e.g. "10:30"
  final String roomName;
  final String subject;

  const ClassSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.roomName,
    required this.subject,
  });

  factory ClassSchedule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClassSchedule(
      id: doc.id,
      dayOfWeek: data['dayOfWeek'] as String? ?? '',
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      roomName: data['roomName'] as String? ?? '',
      subject: data['subject'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'roomName': roomName,
    'subject': subject,
  };
}
