import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/app_constants.dart';

class DetectedBeacon {
  final String deviceName;
  final String roomId;
  final int rssi;
  final DateTime lastSeen;
  const DetectedBeacon({
    required this.deviceName,
    required this.roomId,
    required this.rssi,
    required this.lastSeen,
  });
  String get signalLabel => rssi > -50
      ? 'Very strong'
      : rssi > -65
      ? 'Strong'
      : rssi > -80
      ? 'Medium'
      : 'Weak';
  double get signalPercent => ((rssi.clamp(-100, -30) + 100) / 70).clamp(0, 1);
}

class BleScannerService {
  final _beaconsController = StreamController<List<DetectedBeacon>>.broadcast();
  final _isScanning = ValueNotifier(false);
  Future<DetectedBeacon?>? _pending;
  bool _disposed = false;
  StreamSubscription<List<ScanResult>>? _subscription;
  Stream<List<DetectedBeacon>> get beaconsStream => _beaconsController.stream;
  ValueListenable<bool> get isScanning => _isScanning;
  Future<bool> get isAvailable async =>
      !kIsWeb && await FlutterBluePlus.isSupported;
  Future<bool> get isBluetoothOn async =>
      !kIsWeb &&
      await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;

  Future<void> startScanning() async {
    await scanOnce();
  }

  Future<DetectedBeacon?> scanOnce({bool checkPermissions = true}) {
    if (_disposed) return Future.value(null);
    return _pending ??= _scan(
      checkPermissions: checkPermissions,
    ).whenComplete(() => _pending = null);
  }

  Future<DetectedBeacon?> _scan({bool checkPermissions = true}) async {
    if (kIsWeb) {
      throw StateError('Bluetooth scanning is available in the mobile app.');
    }
    if (!await FlutterBluePlus.isSupported) {
      throw StateError('This device does not support Bluetooth scanning.');
    }
    if (checkPermissions && defaultTargetPlatform == TargetPlatform.android) {
      final permissions = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      final denied = permissions.values.where((s) => !s.isGranted);
      if (denied.isNotEmpty) {
        final permanentlyDenied = denied.any((s) => s.isPermanentlyDenied);
        throw StateError(
          permanentlyDenied
              ? 'Bluetooth or location permission is blocked. Open app settings and allow Nearby devices and Precise location.'
              : 'Allow Nearby devices and Precise location permissions, then retry.',
        );
      }
      if (!await Permission.location.serviceStatus.isEnabled) {
        throw StateError(
          'Turn on Location (GPS) in quick settings. Phones like POCO/Xiaomi see no Bluetooth devices while Location is off.',
        );
      }
    }
    final adapter = await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5));
    if (adapter != BluetoothAdapterState.on) {
      throw StateError('Turn on Bluetooth, then retry.');
    }
    if (_disposed) return null;
    _isScanning.value = true;
    final started = DateTime.now();
    final samples = <String, List<int>>{};
    final lastSeen = <String, DateTime>{};
    try {
      _subscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final advName = r.advertisementData.advName;
          final platName = r.device.platformName;
          final name = advName.isNotEmpty ? advName : platName;
          if (!name.startsWith(AppConstants.blePrefix) ||
              r.timeStamp.isBefore(started)) {
            continue;
          }
          if (lastSeen[name] == r.timeStamp) continue;
          (samples[name] ??= []).add(r.rssi);
          lastSeen[name] = r.timeStamp;
        }
      });
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: AppConstants.bleeScanDurationSec),
        continuousUpdates: true,
        androidUsesFineLocation: true,
      );
      await FlutterBluePlus.isScanning
          .where((s) => !s)
          .first
          .timeout(const Duration(seconds: 12));
      if (_disposed) return null;
      final beacons =
          samples.entries
              .where((e) => e.value.isNotEmpty)
              .map((e) {
                final sorted = [...e.value]..sort();
                return DetectedBeacon(
                  deviceName: e.key,
                  roomId: e.key.substring(AppConstants.blePrefix.length),
                  rssi: sorted[sorted.length ~/ 2],
                  lastSeen: lastSeen[e.key]!,
                );
              })
              .where((b) => b.roomId.isNotEmpty)
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
      _beaconsController.add(beacons);
      // A single scan already reports the strongest beacon. Requiring the same
      // room to win a second scan made every one-shot scan return null.
      return beacons.firstOrNull;
    } catch (_) {
      if (!_disposed) _beaconsController.add([]);
      rethrow;
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      await FlutterBluePlus.stopScan();
      if (!_disposed) _isScanning.value = false;
    }
  }

  Future<void> stopScanning() async {
    if (!kIsWeb) await FlutterBluePlus.stopScan();
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    if (!kIsWeb) unawaited(FlutterBluePlus.stopScan());
    _beaconsController.close();
    _isScanning.dispose();
  }
}
