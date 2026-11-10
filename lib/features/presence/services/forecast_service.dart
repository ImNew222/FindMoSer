import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_model.dart';
import '../../../core/user_model.dart';
import '../../attendance/models/schedule_model.dart';
import 'availability_predictor.dart';
import 'location_policy.dart';
import '../../../core/campus_time.dart';

class ForecastService {
  final FirebaseFirestore db;
  ForecastService(this.db);
  static const server = GetOptions(source: Source.server);

  Future<void> recordObservation(String uid, bool available) async {
    final now = DateTime.now();
    final userRef = db.collection('users').doc(uid);
    final locRef = db.collection('locations').doc(uid);
    final scheduleDocs = await userRef.collection('class_schedule').get(server);
    final schedule = scheduleDocs.docs
        .map(ClassSchedule.fromFirestore)
        .toList();
    if (schedule.isEmpty) {
      throw StateError('Add class schedules before recording observations.');
    }
    final local = CampusTime.wallClock(now);
    final slot =
        '${local.year}-${local.month}-${local.day}-${(local.hour * 60 + local.minute) ~/ 30}';
    final observationRef = userRef
        .collection('availability_observations')
        .doc(slot);
    await db.runTransaction((tx) async {
      final profile = await tx.get(userRef);
      final location = await tx.get(locRef);
      if (profile.data()?['researchConsent'] != true ||
          !profile.exists ||
          !location.exists) {
        throw StateError(
          'Enable pilot data collection and location sharing first.',
        );
      }
      final user = AppUser.fromFirestore(profile);
      final loc = FacultyLocation.fromFirestore(location);
      if (!LocationPolicy.canShare(user, loc, now) ||
          !LocationPolicy.isFresh(loc, now)) {
        throw StateError(
          'A fresh shared detection within sharing hours is required.',
        );
      }
      tx.set(observationRef, {
        'recordedAt': FieldValue.serverTimestamp(),
        'available': available,
        'inZone': loc.isWithinCampus,
        'teaching': AvailabilityPredictor.teachingAt(schedule, now),
        'zoneName': loc.publicZone,
        'labelSource': 'faculty_confirmation',
        'expiresAt': Timestamp.fromDate(now.add(const Duration(days: 60))),
      });
    });
    // The label is already saved; forecast refresh failure must not report a failed save.
    try {
      await refresh(uid);
    } catch (_) {
      /* The next periodic refresh retries. */
    }
  }

  Future<void> refresh(String uid) async {
    final now = DateTime.now();
    final profile = await db.collection('users').doc(uid).get(server);
    final location = await db.collection('locations').doc(uid).get(server);
    if (!profile.exists || !location.exists) return;
    final user = AppUser.fromFirestore(profile);
    final loc = FacultyLocation.fromFirestore(location);
    if (profile.data()?['researchConsent'] != true ||
        !LocationPolicy.canShare(user, loc, now) ||
        !LocationPolicy.isFresh(loc, now)) {
      await db.collection('availability_forecasts').doc(uid).delete();
      return;
    }
    final schedules = await db
        .collection('users')
        .doc(uid)
        .collection('class_schedule')
        .get(server);
    final schedule = schedules.docs.map(ClassSchedule.fromFirestore).toList();
    final docs = await db
        .collection('users')
        .doc(uid)
        .collection('availability_observations')
        .where(
          'recordedAt',
          isGreaterThan: Timestamp.fromDate(
            now.subtract(const Duration(days: 60)),
          ),
        )
        .orderBy('recordedAt', descending: true)
        .limit(1000)
        .get(server);
    final history = docs.docs
        .where(
          (d) =>
              d.data()['labelSource'] == 'faculty_confirmation' &&
              d.data()['available'] is bool &&
              d.data()['inZone'] is bool &&
              d.data()['teaching'] is bool,
        )
        .map((d) {
          final m = d.data();
          return AvailabilityObservation(
            recordedAt: (m['recordedAt'] as Timestamp).toDate(),
            available: m['available'] as bool,
            inZone: m['inZone'] as bool,
            teaching: m['teaching'] as bool,
          );
        })
        .toList();
    final predictor = AvailabilityPredictor();
    final result = predictor.predict(
      at: now,
      knowledgeAt: now,
      inZone: loc.isWithinCampus,
      schedule: schedule,
      observations: history,
    );
    final windows = <Map<String, dynamic>>[];
    for (var i = 1; i <= 6; i++) {
      final at = now.add(Duration(minutes: i * 30));
      if (!LocationPolicy.withinHours(user, at) ||
          !LocationPolicy.withinHours(
            user,
            at
                .add(const Duration(minutes: 30))
                .subtract(const Duration(seconds: 1)),
          )) {
        continue;
      }
      if (List.generate(
        30,
        (m) => at.add(Duration(minutes: m)),
      ).any((t) => AvailabilityPredictor.teachingAt(schedule, t))) {
        continue;
      }
      final candidate = predictor.predict(
        at: at,
        knowledgeAt: now,
        inZone: loc.isWithinCampus,
        schedule: schedule,
        observations: history,
      );
      if (candidate.status == 'likely_available') {
        windows.add({
          'startsAt': Timestamp.fromDate(at),
          'endsAt': Timestamp.fromDate(at.add(const Duration(minutes: 30))),
          ...candidate.toMap(),
        });
      }
    }
    // Recheck consent and sharing after reads; a concurrent pause invalidates publication.
    await db.runTransaction((tx) async {
      final latestUser = await tx.get(db.collection('users').doc(uid));
      final latestLoc = await tx.get(db.collection('locations').doc(uid));
      if (latestUser.data()?['researchConsent'] != true ||
          !latestLoc.exists ||
          !LocationPolicy.isFresh(
            FacultyLocation.fromFirestore(latestLoc),
            DateTime.now(),
          ) ||
          !LocationPolicy.canShare(
            AppUser.fromFirestore(latestUser),
            FacultyLocation.fromFirestore(latestLoc),
            DateTime.now(),
          )) {
        return;
      }
      tx.set(db.collection('availability_forecasts').doc(uid), {
        ...result.toMap(),
        'label': result.label,
        'generatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(minutes: 5))),
        'zoneName': loc.publicZone,
        'windows': windows,
        'assumption':
            'Future windows assume the faculty remains in the shared zone.',
      });
    });
  }
}
