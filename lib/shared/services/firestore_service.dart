import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_constants.dart';
import '../../core/user_model.dart';
import '../../core/room_model.dart';
import '../../features/presence/models/location_model.dart';
import '../../features/attendance/models/schedule_model.dart';
import '../../features/presence/services/location_policy.dart';
import '../../features/presence/services/forecast_service.dart';

/// Firestore data operations for FindMoSer
class FirestoreService {
  final FirebaseFirestore _db;
  FirestoreService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  // ─── Users ───

  /// Get a user profile by UID (cache-first for offline support)
  Future<AppUser?> getUserProfile(String uid) async {
    // Try cache first — works offline after initial login
    try {
      final cached = await _db
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get(const GetOptions(source: Source.cache));
      if (cached.exists) return AppUser.fromFirestore(cached);
    } catch (_) {
      // Cache miss — fall through to server
    }

    // Fall back to server
    try {
      final doc = await _db
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return AppUser.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }

  /// Stream a user profile (real-time updates)
  Stream<AppUser?> streamUserProfile(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? AppUser.fromFirestore(doc) : null);
  }

  /// Update user profile fields
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.usersCollection).doc(uid).update(data);
  }

  // ─── Faculty List ───

  /// Get all faculty members (for student search)
  Future<List<AppUser>> getFacultyList() async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleFaculty)
        .orderBy('displayName')
        .get();

    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// Search faculty by name
  Future<List<AppUser>> searchFaculty(String query) async {
    final allFaculty = await getFacultyList();
    final lowerQuery = query.toLowerCase();
    return allFaculty
        .where((f) => f.displayName.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // ─── Rooms ───

  /// Get all rooms
  Future<List<Room>> getRooms() async {
    final snapshot = await _db.collection(AppConstants.roomsCollection).get();

    return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
  }

  /// Get room by beacon ID
  Future<Room?> getRoomByBeaconId(String beaconId) async {
    final snapshot = await _db
        .collection(AppConstants.roomsCollection)
        .where('beaconId', isEqualTo: beaconId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Room.fromFirestore(snapshot.docs.first);
  }

  // ─── Faculty Locations ───

  /// Stream a faculty member's real-time location
  Stream<FacultyLocation?> streamFacultyLocation(String facultyId) {
    return _db
        .collection(AppConstants.locationsCollection)
        .doc(facultyId)
        .snapshots()
        .map((doc) => doc.exists ? FacultyLocation.fromFirestore(doc) : null);
  }

  /// Get a faculty member's location (one-time read)
  Future<FacultyLocation?> getFacultyLocation(String facultyId) async {
    final doc = await _db
        .collection(AppConstants.locationsCollection)
        .doc(facultyId)
        .get();

    if (!doc.exists) return null;
    return FacultyLocation.fromFirestore(doc);
  }

  /// Get all active faculty locations
  Future<List<FacultyLocation>> getAllFacultyLocations() async {
    final snapshot = await _db
        .collection(AppConstants.locationsCollection)
        .get();

    return snapshot.docs
        .map((doc) => FacultyLocation.fromFirestore(doc))
        .toList();
  }

  /// Update a faculty member's location (called by BLE scanner)
  Future<bool> updateFacultyLocation({
    required String facultyId,
    required String roomId,
    required String beaconId,
  }) async {
    final mapped = await getRoomByBeaconId(beaconId);
    String zone = roomId;
    if (mapped != null) {
      final mapDoc = await _db
          .collection(AppConstants.roomsCollection)
          .doc(mapped.id)
          .get();
      final z = mapDoc.data()?['zoneName'] as String?;
      if (z != null && z.trim().isNotEmpty) {
        zone = z;
      }
    }
    final reference = _db
        .collection(AppConstants.locationsCollection)
        .doc(facultyId);
    return _db.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      final profile = await transaction.get(
        _db.collection(AppConstants.usersCollection).doc(facultyId),
      );
      if (!profile.exists ||
          !LocationPolicy.withinHours(
            AppUser.fromFirestore(profile),
            DateTime.now(),
          )) {
        return false;
      }
      // A concurrent pause retries this transaction and prevents the update.
      if (existing.data()?['isVisible'] != true) return false;
      transaction.update(reference, {
        'zoneName': zone,
        'currentRoom': roomId,
        'beaconId': beaconId,
        'timestamp': FieldValue.serverTimestamp(),
        'isWithinCampus': true,
      });
      return true;
    });
  }

  /// Toggle faculty visibility (privacy toggle)
  Future<void> setFacultyVisibility({
    required String facultyId,
    required bool isVisible,
  }) async {
    await _db.collection(AppConstants.locationsCollection).doc(facultyId).set({
      'isVisible': isVisible,
      'settingsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!isVisible) {
      await _db.collection('availability_forecasts').doc(facultyId).delete();
    }
  }

  Future<void> refreshForecast(String uid) => ForecastService(_db).refresh(uid);

  // ─── Location History (for AI predictions) ───

  /// Log a location entry for AI prediction data
  Future<void> logLocationEntry({
    required String facultyId,
    required String roomId,
    required String dayOfWeek,
    required String arrivalTime,
  }) async {
    await _db
        .collection(AppConstants.locationHistoryCollection)
        .doc(facultyId)
        .collection('logs')
        .add({
          'roomId': roomId,
          'dayOfWeek': dayOfWeek,
          'arrivalTime': arrivalTime,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  /// Get historical location logs for a faculty on a specific day
  Future<List<Map<String, dynamic>>> getHistoricalLocations({
    required String facultyId,
    required String dayOfWeek,
  }) async {
    final snapshot = await _db
        .collection(AppConstants.locationHistoryCollection)
        .doc(facultyId)
        .collection('logs')
        .where('dayOfWeek', whereIn: [dayOfWeek, dayOfWeek.substring(0, 3)])
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ─── Class Schedule ───

  /// Stream a faculty member's class schedule
  Stream<List<ClassSchedule>> streamFacultySchedule(String facultyId) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(facultyId)
        .collection('class_schedule')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClassSchedule.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a faculty member's class schedule (one-time read)
  Future<List<ClassSchedule>> getFacultySchedule(String facultyId) async {
    final snapshot = await _db
        .collection(AppConstants.usersCollection)
        .doc(facultyId)
        .collection('class_schedule')
        .get();

    return snapshot.docs
        .map((doc) => ClassSchedule.fromFirestore(doc))
        .toList();
  }

  /// Add a new class schedule
  Future<void> addClassSchedule({
    required String facultyId,
    required ClassSchedule schedule,
  }) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(facultyId)
        .collection('class_schedule')
        .add(schedule.toFirestore());
  }

  /// Delete a class schedule
  Future<void> deleteClassSchedule({
    required String facultyId,
    required String scheduleId,
  }) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(facultyId)
        .collection('class_schedule')
        .doc(scheduleId)
        .delete();
  }
}
