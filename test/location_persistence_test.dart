import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:findmoser_app/services/firestore_service.dart';
import 'package:findmoser_app/models/location_model.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = FirestoreService(db: db);
    await db.collection('users').doc('one').set({'role': 'faculty'});
  });
  test('changing visibility does not refresh detection time', () async {
    final timestamp = Timestamp.fromDate(DateTime(2020));
    await db.collection('locations').doc('one').set({
      'timestamp': timestamp,
      'isVisible': true,
    });
    await service.setFacultyVisibility(facultyId: 'one', isVisible: false);
    final data = (await db.collection('locations').doc('one').get()).data()!;
    expect(data['timestamp'], timestamp);
    expect(data['isVisible'], false);
    expect(data.containsKey('settingsUpdatedAt'), true);
  });
  test('a scan cannot turn paused sharing back on', () async {
    await db.collection('locations').doc('one').set({
      'isVisible': false,
      'currentRoom': 'old',
    });
    final updated = await service.updateFacultyLocation(
      facultyId: 'one',
      roomId: 'new',
      beaconId: 'b',
    );
    expect(updated, false);
    final data = (await db.collection('locations').doc('one').get()).data()!;
    expect(data['isVisible'], false);
    expect(data['currentRoom'], 'old');
  });
  test('no location record requires explicit opt in', () async {
    expect(
      await service.updateFacultyLocation(
        facultyId: 'one',
        roomId: 'new',
        beaconId: 'b',
      ),
      false,
    );
  });
  test('visible location accepts detection updates', () async {
    await db.collection('locations').doc('one').set({'isVisible': true});
    expect(
      await service.updateFacultyLocation(
        facultyId: 'one',
        roomId: 'new',
        beaconId: 'b',
      ),
      true,
    );
    expect(
      (await db.collection('locations').doc('one').get())
          .data()!['currentRoom'],
      'new',
    );
  });
  test(
    'a visibility-only document is never treated as a fresh location',
    () async {
      await service.setFacultyVisibility(facultyId: 'one', isVisible: true);
      final loc = FacultyLocation.fromFirestore(
        await db.collection('locations').doc('one').get(),
      );
      expect(loc.timestamp.millisecondsSinceEpoch, 0);
      expect(loc.timeAgo, 'Time unknown');
    },
  );
  test('historical lookup supports legacy abbreviated weekdays', () async {
    await service.logLocationEntry(
      facultyId: 'one',
      roomId: 'A',
      dayOfWeek: 'Mon',
      arrivalTime: '08:00',
    );
    await service.logLocationEntry(
      facultyId: 'one',
      roomId: 'B',
      dayOfWeek: 'Monday',
      arrivalTime: '09:00',
    );
    expect(
      (await service.getHistoricalLocations(
        facultyId: 'one',
        dayOfWeek: 'Monday',
      )).length,
      2,
    );
  });
}
