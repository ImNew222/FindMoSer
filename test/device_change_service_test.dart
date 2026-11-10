import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/features/auth/services/device_change_service.dart';

void main() {
  test(
    'request is scoped to the signed-in student and current device',
    () async {
      final db = FakeFirebaseFirestore();
      final service = DeviceChangeService(
        db: db,
        currentUid: () => 'student-one',
        readDeviceId: () async => '0123456789abcdef',
      );
      await service.requestChange('  My original phone was damaged.  ');
      final request = await service.currentRequest();
      expect(request?['studentId'], 'student-one');
      expect(request?['newDeviceId'], '0123456789abcdef');
      expect(request?['reason'], 'My original phone was damaged.');
      expect(request?['status'], 'pending');
      expect(request?['requestedAt'], isNotNull);
      await expectLater(
        service.requestChange('Replace the existing pending request.'),
        throwsStateError,
      );
      expect(
        (await service.currentRequest())?['reason'],
        'My original phone was damaged.',
      );
    },
  );

  test('a resolved request can be followed by a new request', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('device_change_requests').doc('student-one').set({
      'status': 'rejected',
      'reason': 'Old request',
    });
    final service = DeviceChangeService(
      db: db,
      currentUid: () => 'student-one',
      readDeviceId: () async => '0123456789abcdef',
    );
    await service.requestChange('I have replaced my damaged phone.');
    expect((await service.currentRequest())?['status'], 'pending');
  });

  test('rejects unsigned requests and missing explanations', () async {
    final db = FakeFirebaseFirestore();
    final signedOut = DeviceChangeService(db: db, currentUid: () => null);
    await expectLater(
      signedOut.requestChange('My phone was damaged.'),
      throwsStateError,
    );
    final signedIn = DeviceChangeService(
      db: db,
      currentUid: () => 'student-one',
    );
    await expectLater(signedIn.requestChange('short'), throwsArgumentError);
    await expectLater(signedIn.requestChange('x' * 501), throwsArgumentError);
    expect((await db.collection('device_change_requests').get()).docs, isEmpty);
  });
}
