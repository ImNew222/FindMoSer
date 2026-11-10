import 'package:cloud_firestore/cloud_firestore.dart';

/// A deliberately small, student-readable projection of a faculty member.
/// It never contains email, device IDs, enrollment lists or private schedule
/// data, so the directory can be listed without exposing user profiles.
class FacultyPresence {
  final String facultyId;
  final String displayName;
  final String department;
  final String availability;
  final String zoneName;
  final String currentRoom;
  final String beaconId;
  final DateTime updatedAt;
  final bool isSharing;
  final String? workStartTime;
  final String? workEndTime;

  const FacultyPresence({
    required this.facultyId,
    required this.displayName,
    required this.department,
    this.availability = 'unset',
    this.zoneName = '',
    this.currentRoom = '',
    this.beaconId = '',
    required this.updatedAt,
    this.isSharing = false,
    this.workStartTime,
    this.workEndTime,
  });

  bool get hasLocation => isSharing && currentRoom.isNotEmpty;
  String get publicZone {
    if (zoneName.trim().isNotEmpty && zoneName.trim() != 'Shared campus zone') {
      return zoneName;
    }
    if (currentRoom.trim().isNotEmpty) {
      return currentRoom;
    }
    return 'Shared campus zone';
  }

  bool isFresh(DateTime now) {
    final age = now.difference(updatedAt);
    return !age.isNegative && age < const Duration(minutes: 5);
  }

  factory FacultyPresence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FacultyPresence(
      facultyId: doc.id,
      displayName: data['displayName'] as String? ?? 'Faculty',
      department: data['department'] as String? ?? '',
      availability: data['availability'] as String? ?? 'unset',
      zoneName: data['zoneName'] as String? ?? '',
      currentRoom: data['currentRoom'] as String? ?? '',
      beaconId: data['beaconId'] as String? ?? '',
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isSharing: data['isSharing'] == true,
      workStartTime: data['workStartTime'] as String?,
      workEndTime: data['workEndTime'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'displayName': displayName,
    'department': department,
    'availability': availability,
    'zoneName': zoneName,
    'currentRoom': currentRoom,
    'beaconId': beaconId,
    // Preserve the beacon detection time. A server timestamp here would make
    // a stale room look freshly detected after every sync.
    'updatedAt': Timestamp.fromDate(updatedAt),
    'isSharing': isSharing,
    if (workStartTime != null) 'workStartTime': workStartTime,
    if (workEndTime != null) 'workEndTime': workEndTime,
  };

  FacultyPresence copyWith({
    String? displayName,
    String? department,
    String? availability,
    String? zoneName,
    String? currentRoom,
    String? beaconId,
    bool? isSharing,
    String? workStartTime,
    String? workEndTime,
  }) => FacultyPresence(
    facultyId: facultyId,
    displayName: displayName ?? this.displayName,
    department: department ?? this.department,
    availability: availability ?? this.availability,
    zoneName: zoneName ?? this.zoneName,
    currentRoom: currentRoom ?? this.currentRoom,
    beaconId: beaconId ?? this.beaconId,
    updatedAt: updatedAt,
    isSharing: isSharing ?? this.isSharing,
    workStartTime: workStartTime ?? this.workStartTime,
    workEndTime: workEndTime ?? this.workEndTime,
  );
}
