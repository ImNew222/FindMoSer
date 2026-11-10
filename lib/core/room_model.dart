import 'package:cloud_firestore/cloud_firestore.dart';

/// Room model — represents a physical room with a BLE beacon installed
class Room {
  final String id; // Document ID, e.g., "AC-205"
  final String building; // e.g., "AC Building"
  final int floor;
  final String roomName; // Display name, e.g., "AC-205"
  final String beaconId; // Maps to physical beacon, e.g., "FindMoSer_AC-205"
  final double? latitude;
  final double? longitude;

  const Room({
    required this.id,
    required this.building,
    required this.floor,
    required this.roomName,
    required this.beaconId,
    this.latitude,
    this.longitude,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Room(
      id: doc.id,
      building: data['building'] as String? ?? '',
      floor: switch (data['floor']) {
        int i => i,
        num n => n.toInt(),
        String s => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 1,
        _ => 1,
      },
      roomName: data['roomName'] as String? ?? doc.id,
      beaconId: data['beaconId'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'building': building,
    'floor': floor,
    'roomName': roomName,
    'beaconId': beaconId,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}
