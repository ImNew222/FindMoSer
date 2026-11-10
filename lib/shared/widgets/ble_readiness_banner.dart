import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_theme.dart';

enum BleReadiness {
  ready,
  unsupported,
  bluetoothDenied,
  locationDenied,
  locationServicesOff,
}

/// Android needs Nearby devices plus Precise location (and Location services
/// switched on) before a classroom beacon can be detected.
Future<BleReadiness> checkBleReadiness({bool request = false}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return BleReadiness.ready;
  }
  try {
    if (!await FlutterBluePlus.isSupported) return BleReadiness.unsupported;
    final needed = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    final statuses = request
        ? await needed.request()
        : {
            for (final permission in needed)
              permission: await permission.status,
          };
    if (!(statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
        !(statuses[Permission.bluetoothConnect]?.isGranted ?? false)) {
      return BleReadiness.bluetoothDenied;
    }
    if (!(statuses[Permission.locationWhenInUse]?.isGranted ?? false)) {
      return BleReadiness.locationDenied;
    }
    if (!await Permission.location.serviceStatus.isEnabled) {
      return BleReadiness.locationServicesOff;
    }
    return BleReadiness.ready;
  } catch (_) {
    return BleReadiness.unsupported;
  }
}

/// Asks once when the dashboard opens and explains (with a fix action) when
/// scanning prerequisites are still missing.
class BleReadinessBanner extends StatefulWidget {
  const BleReadinessBanner({super.key});
  @override
  State<BleReadinessBanner> createState() => _BleReadinessBannerState();
}

class _BleReadinessBannerState extends State<BleReadinessBanner>
    with WidgetsBindingObserver {
  BleReadiness? _status;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final status = await checkBleReadiness();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _ask() async {
    if (_asking || !mounted) return;
    _asking = true;
    final status = await checkBleReadiness(request: true);
    _asking = false;
    if (mounted) setState(() => _status = status);
  }

  Future<void> _fix() async {
    if (_status == BleReadiness.locationServicesOff) {
      try {
        await const MethodChannel(
          'findmoser/system_settings',
        ).invokeMethod('openLocationSettings');
      } catch (_) {
        await openAppSettings();
      }
      return;
    }
    final blocked = (await Future.wait([
      Permission.bluetoothScan.status,
      Permission.locationWhenInUse.status,
    ])).any((status) => status.isPermanentlyDenied);
    if (blocked) {
      await openAppSettings();
      return;
    }
    await _ask();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || status == BleReadiness.ready) {
      return const SizedBox.shrink();
    }
    final (message, action) = switch (status) {
      BleReadiness.unsupported => (
        'This phone cannot scan for classroom beacons.',
        null,
      ),
      BleReadiness.bluetoothDenied => (
        'Bluetooth scanning is off. Allow Nearby devices so beacons can be detected.',
        'Allow',
      ),
      BleReadiness.locationDenied => (
        'Precise location is off. Android needs it for Bluetooth scanning.',
        'Allow',
      ),
      BleReadiness.locationServicesOff => (
        'Location (GPS) is off. Phones like POCO/Xiaomi find no beacons until it is on.',
        'Settings',
      ),
      BleReadiness.ready => ('', null),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          if (action != null) TextButton(onPressed: _fix, child: Text(action)),
        ],
      ),
    );
  }
}
