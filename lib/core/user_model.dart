import 'package:cloud_firestore/cloud_firestore.dart';

/// Schedule entry for a faculty member (one day)
class Schedule {
  final String day; // e.g., "Monday"
  final String start; // e.g., "08:00"
  final String end; // e.g., "17:00"

  const Schedule({required this.day, required this.start, required this.end});

  factory Schedule.fromMap(Map<String, dynamic> map) {
    return Schedule(
      day: map['day'] as String? ?? '',
      start: map['start'] as String? ?? '',
      end: map['end'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'day': day, 'start': start, 'end': end};
}

/// User model — represents both Students and Faculty
class AppUser {
  final String availability;
  final String uid;
  final String displayName;
  final String email;
  final String role; // 'student' or 'faculty'
  final String department;
  final String? profilePhotoUrl;
  final List<Schedule>? schedule; // Faculty only
  final String? workStartTime; // e.g. "08:00"
  final String? workEndTime; // e.g. "17:00"
  final DateTime? createdAt;
  // Retained for reading legacy locator profiles; attendance uses fixed beacons.
  final String? beaconMacAddress;
  final String? deviceId; // Android app-scoped device identifier
  final String? schoolId;
  final bool facultyApproved;

  const AppUser({
    this.availability = 'unset',
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.department,
    this.profilePhotoUrl,
    this.schedule,
    this.workStartTime,
    this.workEndTime,
    this.createdAt,
    this.beaconMacAddress,
    this.deviceId,
    this.schoolId,
    this.facultyApproved = false,
  });

  bool get isFaculty => role == 'faculty';
  bool get hasFacultyAccess => isFaculty && facultyApproved;
  bool get isStudent => role == 'student';

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      availability: data['availability'] as String? ?? 'unset',
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      department: data['department'] as String? ?? '',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      schedule: data['schedule'] != null
          ? (data['schedule'] as List)
                .map((s) => Schedule.fromMap(s as Map<String, dynamic>))
                .toList()
          : null,
      workStartTime: data['workStartTime'] as String?,
      workEndTime: data['workEndTime'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      beaconMacAddress: data['beaconMacAddress'] as String?,
      deviceId: data['deviceId'] as String?,
      schoolId: data['schoolId'] as String?,
      facultyApproved: data['facultyApproved'] == true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'availability': availability,
    'displayName': displayName,
    'email': email,
    'role': role,
    'facultyApproved': facultyApproved,
    'department': department,
    if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
    if (schedule != null) 'schedule': schedule!.map((s) => s.toMap()).toList(),
    if (workStartTime != null) 'workStartTime': workStartTime,
    if (workEndTime != null) 'workEndTime': workEndTime,
    if (beaconMacAddress != null) 'beaconMacAddress': beaconMacAddress,
    if (deviceId != null) 'deviceId': deviceId,
    if (schoolId != null) 'schoolId': schoolId,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  AppUser copyWith({
    String? displayName,
    String? email,
    String? role,
    String? department,
    String? profilePhotoUrl,
    List<Schedule>? schedule,
    String? workStartTime,
    String? workEndTime,
    String? beaconMacAddress,
    String? deviceId,
    String? schoolId,
    String? availability,
  }) {
    return AppUser(
      availability: availability ?? this.availability,
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      department: department ?? this.department,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      schedule: schedule ?? this.schedule,
      workStartTime: workStartTime ?? this.workStartTime,
      workEndTime: workEndTime ?? this.workEndTime,
      createdAt: createdAt,
      beaconMacAddress: beaconMacAddress ?? this.beaconMacAddress,
      deviceId: deviceId ?? this.deviceId,
      schoolId: schoolId ?? this.schoolId,
      facultyApproved: facultyApproved,
    );
  }
}
