import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/services/forecast_service.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ForecastService service;
  setUp(() async {
    db = FakeFirebaseFirestore();
    service = ForecastService(db);
    await db.collection('users').doc('faculty').set({
      'role': 'faculty',
      'researchConsent': true,
    });
    await db.collection('locations').doc('faculty').set({
      'isVisible': true,
      'timestamp': Timestamp.now(),
      'zoneName': 'IT Department',
      'currentRoom': 'Private room',
    });
    await db
        .collection('users')
        .doc('faculty')
        .collection('class_schedule')
        .doc('a')
        .set({'dayOfWeek': 'Monday', 'startTime': '09:00', 'endTime': '10:00'});
  });
  test('consent is required before writing a label', () async {
    await db.collection('users').doc('faculty').update({
      'researchConsent': false,
    });
    await expectLater(
      service.recordObservation('faculty', true),
      throwsStateError,
    );
    expect(
      (await db
              .collection('users')
              .doc('faculty')
              .collection('availability_observations')
              .get())
          .docs,
      isEmpty,
    );
  });
  test('stale detection cannot supply a new label', () async {
    await db.collection('locations').doc('faculty').update({
      'timestamp': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(minutes: 6)),
      ),
    });
    await expectLater(
      service.recordObservation('faculty', true),
      throwsStateError,
    );
  });
  test('saved label contains confirmation and zone but no room', () async {
    await service.recordObservation('faculty', false);
    final docs =
        (await db
                .collection('users')
                .doc('faculty')
                .collection('availability_observations')
                .get())
            .docs;
    expect(docs, hasLength(1));
    final label = docs.single.data();
    expect(label['available'], false);
    expect(label['labelSource'], 'faculty_confirmation');
    expect(label['zoneName'], 'IT Department');
    expect(label.containsKey('currentRoom'), false);
    final forecast =
        (await db.collection('availability_forecasts').doc('faculty').get())
            .data()!;
    expect(forecast['status'], isNot('likely_available'));
    expect(forecast['windows'], isEmpty);
  });
  test('refresh removes estimate after sharing is paused', () async {
    await db.collection('availability_forecasts').doc('faculty').set({
      'status': 'likely_available',
    });
    await db.collection('locations').doc('faculty').update({
      'isVisible': false,
    });
    await service.refresh('faculty');
    expect(
      (await db.collection('availability_forecasts').doc('faculty').get())
          .exists,
      false,
    );
  });
}
