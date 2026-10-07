import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/location_model.dart';
import '../../models/schedule_model.dart';
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

  @override
  Future<List<AppUser>> faculty() async {
    final docs = await db
        .collection('users')
        .where('role', isEqualTo: 'faculty')
        .get(server);
    return docs.docs.map(AppUser.fromFirestore).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<FacultyLocation?> location(String id) async {
    final doc = await db.collection('locations').doc(id).get(server);
    return doc.exists ? FacultyLocation.fromFirestore(doc) : null;
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
