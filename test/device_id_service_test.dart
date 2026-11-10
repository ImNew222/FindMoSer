import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/features/auth/services/device_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('findmoser/device_id');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('reads the native channel and normalizes a valid ID', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getAndroidId');
      return ' ABCDEF0123456789 ';
    });
    expect(await DeviceIdService.getDeviceId(), 'abcdef0123456789');
  });

  test('invalid IDs never receive a fallback identifier', () async {
    for (final value in [
      null,
      '',
      'unknown',
      '0000000000000000',
      '9774d56d682e549c',
      '0123456789abcdeg',
      '0123',
    ]) {
      messenger.setMockMethodCallHandler(channel, (_) async => value);
      await expectLater(
        DeviceIdService.getDeviceId(),
        throwsA(isA<DeviceIdUnavailable>()),
      );
    }
  });

  test('native failure and missing plugin fail closed', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'UNAVAILABLE');
    });
    await expectLater(
      DeviceIdService.getDeviceId(),
      throwsA(isA<DeviceIdUnavailable>()),
    );
    messenger.setMockMethodCallHandler(channel, null);
    await expectLater(
      DeviceIdService.getDeviceId(),
      throwsA(isA<DeviceIdUnavailable>()),
    );
  });

  test('unsupported platform cannot register attendance devices', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await expectLater(
      DeviceIdService.getDeviceId(),
      throwsA(isA<DeviceIdUnavailable>()),
    );
  });
}
