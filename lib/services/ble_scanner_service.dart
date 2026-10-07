import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_constants.dart';
import 'beacon_stability.dart';

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
  final _stability = BeaconStability();
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
    return _pending ??= _scan(checkPermissions: checkPermissions).whenComplete(() => _pending = null);
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
      if (permissions.values.any((status) => !status.isGranted)) {
        throw StateError(
          'Allow Bluetooth and location permissions in device settings, then retry.',
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
          final name = r.advertisementData.advName;
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
              .where((b) => b.rssi >= -80 && b.roomId.isNotEmpty)
              .toList()
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
      _beaconsController.add(beacons);
      final room = _stability.observe(
        beacons.isEmpty ? null : beacons.first.roomId,
      );
      return room == null
          ? null
          : beacons.where((b) => b.roomId == room).firstOrNull;
    } catch (_) {
      _stability.observe(null);
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
