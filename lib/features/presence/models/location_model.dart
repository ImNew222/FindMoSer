import 'package:cloud_firestore/cloud_firestore.dart';

/// FacultyLocation — real-time location of a faculty member
class FacultyLocation {
  final String zoneName;
  String get publicZone {
    if (zoneName.trim().isNotEmpty && zoneName.trim() != 'Shared campus zone') {
      return zoneName;
    }
    if (currentRoom.trim().isNotEmpty) {
      return currentRoom;
    }
    return 'Shared campus zone';
  }
  final String facultyId;
  final String currentRoom;
  final String beaconId;
  final DateTime timestamp;
  final bool isVisible; // Privacy toggle
  final bool isWithinCampus; // Geofence check

  const FacultyLocation({
    this.zoneName = '',
    required this.facultyId,
    required this.currentRoom,
    required this.beaconId,
    required this.timestamp,
    this.isVisible = true,
    this.isWithinCampus = true,
  });

  /// How long ago the location was updated
  String get timeAgo {
    if (timestamp.millisecondsSinceEpoch == 0) return 'Time unknown';
    final diff = DateTime.now().difference(timestamp);
    if (diff.isNegative) return 'Time unverified';
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  factory FacultyLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FacultyLocation(
      zoneName: data['zoneName'] as String? ?? '',
      facultyId: doc.id,
      currentRoom: data['currentRoom'] as String? ?? '',
      beaconId: data['beaconId'] as String? ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isVisible: data['isVisible'] as bool? ?? false,
      isWithinCampus: data['isWithinCampus'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'zoneName': zoneName,
    'currentRoom': currentRoom,
    'beaconId': beaconId,
    'timestamp': FieldValue.serverTimestamp(),
    'isVisible': isVisible,
    'isWithinCampus': isWithinCampus,
  };
}

/// LocationLog — historical location entry for AI predictions
class LocationLog {
  final String roomId;
  final String dayOfWeek;
  final String arrivalTime;
  final String? departureTime;
  final DateTime timestamp;

  const LocationLog({
    required this.roomId,
    required this.dayOfWeek,
    required this.arrivalTime,
    this.departureTime,
    required this.timestamp,
  });

  factory LocationLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LocationLog(
      roomId: data['roomId'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as String? ?? '',
      arrivalTime: data['arrivalTime'] as String? ?? '',
      departureTime: data['departureTime'] as String?,
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'roomId': roomId,
    'dayOfWeek': dayOfWeek,
    'arrivalTime': arrivalTime,
    if (departureTime != null) 'departureTime': departureTime,
    'timestamp': FieldValue.serverTimestamp(),
  };
}
