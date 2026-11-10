import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/user_model.dart';
import '../../presence/models/location_model.dart';
import '../../attendance/models/schedule_model.dart';
import 'faculty_assistant.dart';

/// Assistant answers require a server response. Offline cache must not be
/// described as records checked now.
class FirestoreFacultyRepository
    implements FacultyRepository, ForecastRepository {
  final FirebaseFirestore db;
  FirestoreFacultyRepository(this.db);
  static const server = GetOptions(source: Source.server);
  @override
  Future<String?> forecastSummary(String id) async {
    final doc = await db
        .collection('availability_forecasts')
        .doc(id)
        .get(server);
    final data = doc.data();
    final expires = (data?['expiresAt'] as Timestamp?)?.toDate();
    if (data == null || expires == null || !expires.isAfter(DateTime.now())) {
      return null;
    }
    return 'Pilot estimate: ${data['label']}. ${data['reason']}';
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getPresenceCollection() async {
    try {
      return await db
          .collection('faculty_presence')
          .get(server)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return await db.collection('faculty_presence').get();
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getPresenceDoc(String id) async {
    try {
      return await db
          .collection('faculty_presence')
          .doc(id)
          .get(server)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return await db.collection('faculty_presence').doc(id).get();
    }
  }

  @override
  Future<List<AppUser>> faculty() async {
    // Students cannot list users; the presence projection is the directory.
    final docs = await _getPresenceCollection();
    return docs.docs.map((doc) {
      final data = doc.data();
      return AppUser(
        uid: doc.id,
        displayName: data['displayName'] as String? ?? 'Faculty',
        email: '',
        role: 'faculty',
        department: data['department'] as String? ?? '',
        availability: data['availability'] as String? ?? 'unset',
        workStartTime: data['workStartTime'] as String?,
        workEndTime: data['workEndTime'] as String?,
      );
    }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<FacultyLocation?> location(String id) async {
    final doc = await _getPresenceDoc(id);
    final data = doc.data();
    if (data == null || data['isSharing'] != true) return null;
    return FacultyLocation(
      facultyId: id,
      zoneName: data['zoneName'] as String? ?? '',
      currentRoom: data['currentRoom'] as String? ?? '',
      beaconId: data['beaconId'] as String? ?? '',
      timestamp:
          (data['updatedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isVisible: true,
      isWithinCampus: true,
    );
  }

  @override
  Future<List<ClassSchedule>> schedule(String id) async {
    final docs = await db
        .collection('users')
        .doc(id)
        .collection('class_schedule')
        .get(server);
    return docs.docs.map(ClassSchedule.fromFirestore).toList();
  }
}
