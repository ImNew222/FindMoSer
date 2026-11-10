import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_constants.dart';
import '../models/location_model.dart';
import '../models/presence_model.dart';
import '../../../core/user_model.dart';
import 'location_policy.dart';

/// Publishes a public directory projection for approved faculty.
///
/// Students cannot list `users`, so the presence collection is the only
/// student-readable faculty directory. It is kept intentionally minimal and is
/// updated whenever sharing, availability or a detected room changes.
class PresenceService {
  final FirebaseFirestore _db;
  PresenceService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  static const collection = 'faculty_presence';

  Future<void> sync(
    String facultyId, {
    String? availabilityOverride,
    String? startOverride,
    String? endOverride,
  }) async {
    final profileDoc = await _db
        .collection(AppConstants.usersCollection)
        .doc(facultyId)
        .get();
    if (!profileDoc.exists) return;
    final profile = AppUser.fromFirestore(profileDoc);
    if (!profile.hasFacultyAccess) {
      await _db.collection(collection).doc(facultyId).delete();
      return;
    }
    final locationRef = _db
        .collection(AppConstants.locationsCollection)
        .doc(facultyId);
    var locationDoc = await locationRef.get();
    if (!locationDoc.exists) {
      // Sharing defaults to on, but no room is published until a beacon is
      // detected. Creating the document lets the location updater work.
      await locationRef.set({
        'isVisible': true,
        'isWithinCampus': false,
        'currentRoom': '',
        'beaconId': '',
        'zoneName': '',
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(0),
      }, SetOptions(merge: true));
      locationDoc = await locationRef.get();
    }
    final location = FacultyLocation.fromFirestore(locationDoc);
    final now = DateTime.now();
    final effectiveProfile = profile.copyWith(
      availability: availabilityOverride,
      workStartTime: startOverride,
      workEndTime: endOverride,
    );
    final sharing = LocationPolicy.canShare(effectiveProfile, location, now);
    final presence = FacultyPresence(
      facultyId: facultyId,
      displayName: effectiveProfile.displayName,
      department: effectiveProfile.department,
      availability: effectiveProfile.availability,
      zoneName: sharing ? location.publicZone : '',
      currentRoom: sharing ? location.currentRoom : '',
      beaconId: sharing ? location.beaconId : '',
      updatedAt: DateTime.now(),
      isSharing: sharing,
      workStartTime: effectiveProfile.workStartTime,
      workEndTime: effectiveProfile.workEndTime,
    );
    // Replace rather than merge so cleared hours or a hidden room cannot
    // survive in the public projection.
    await _db.collection(collection).doc(facultyId).set(presence.toFirestore());
  }

  Future<void> setAvailability(String facultyId, String availability) async {
    await _db.collection(AppConstants.usersCollection).doc(facultyId).update({
      'availability': availability,
    });
    await sync(facultyId, availabilityOverride: availability);
  }

  Future<void> setSharingHours(
    String facultyId, {
    required String start,
    required String end,
  }) async {
    await _db.collection(AppConstants.usersCollection).doc(facultyId).update({
      'workStartTime': start,
      'workEndTime': end,
    });
    await sync(facultyId, startOverride: start, endOverride: end);
  }

  Future<void> setSharing(String facultyId, bool isVisible) async {
    await _db.collection(AppConstants.locationsCollection).doc(facultyId).set({
      'isVisible': isVisible,
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await sync(facultyId);
  }
}
