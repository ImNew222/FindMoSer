import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceIdUnavailable implements Exception {
  final String message;
  const DeviceIdUnavailable(this.message);
  @override
  String toString() => message;
}

/// Android's app-signing-key/user/device-scoped ID, not a hardware serial.
/// It can change after a factory reset or signing-key change. Never substitute a
/// shared or random identifier: that would defeat account/device binding.
class DeviceIdService {
  static const _channel = MethodChannel('findmoser/device_id');

  static Future<String> getDeviceId() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const DeviceIdUnavailable(
        'Student registration and attendance require the Android app.',
      );
    }
    try {
      final value = await _channel
          .invokeMethod<String>('getAndroidId')
          .timeout(const Duration(seconds: 8));
      final id = value?.trim().toLowerCase();
      if (id == null ||
          !RegExp(r'^[0-9a-f]{16}$').hasMatch(id) ||
          id == '0000000000000000' ||
          id == '9774d56d682e549c') {
        throw const DeviceIdUnavailable(
          'This phone did not provide a valid device identifier. Contact the project team.',
        );
      }
      return id;
    } on PlatformException {
      throw const DeviceIdUnavailable(
        'Unable to verify this Android device. Restart the app and try again.',
      );
    } on MissingPluginException {
      throw const DeviceIdUnavailable(
        'Device verification is unavailable. Install the latest Android APK.',
      );
    } on TimeoutException {
      throw const DeviceIdUnavailable(
        'Device verification timed out. Restart the app and try again.',
      );
    }
  }
}
