import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassSchedule {
  final String id;
  final String dayOfWeek; // e.g. "Monday"
  final String startTime; // e.g. "09:00"
  final String endTime; // e.g. "10:30"
  final String roomName;
  final String subject;
  final String joinCode;

  const ClassSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.roomName,
    required this.subject,
    this.joinCode = '',
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
      joinCode: data['joinCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'roomName': roomName,
    'subject': subject,
    if (joinCode.isNotEmpty) 'joinCode': joinCode,
  };
}

/// Short, unambiguous class code students type to enroll themselves.
class JoinCode {
  JoinCode._();

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate([int length = 6]) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  static String normalize(String value) =>
      value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
