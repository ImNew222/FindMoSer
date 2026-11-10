import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/services/ble_scanner_service.dart';
import '../../../shared/services/firestore_service.dart';
import '../services/presence_service.dart';
import '../../../core/app_constants.dart';
import '../services/location_policy.dart';

// ─── BLE Scanner Instance ───

final bleScannerProvider = Provider<BleScannerService>((ref) {
  final scanner = BleScannerService();
  ref.onDispose(() => scanner.dispose());
  return scanner;
});

// ─── Faculty Location Auto-Updater ───
// Used on faculty dashboard to periodically scan and update Firestore

class FacultyLocationUpdater {
  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  DateTime? _lastForecast;
  DateTime? _lastPresenceSync;
  final BleScannerService scanner;
  final FirestoreService firestoreService;
  final PresenceService presenceService;
  final String facultyId;

  FacultyLocationUpdater({
    required this.scanner,
    required this.firestoreService,
    required this.presenceService,
    required this.facultyId,
  });

  /// Start periodic scanning and location updates
  void start() {
    if (_running) return;
    _running = true;
    // Do an immediate scan
    _scanAndUpdate();

    // Then scan every N seconds
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.locationUpdateIntervalSec),
      (_) => _scanAndUpdate(),
    );
  }

  Future<void> _scanAndUpdate() async {
    if (kIsWeb || !_running || _busy) return;
    _busy = true;
    try {
      final profile = await firestoreService.getUserProfile(facultyId);
      final location = await firestoreService.getFacultyLocation(facultyId);
      if (!_running || profile == null || location?.isVisible != true) return;
      if (!LocationPolicy.withinHours(profile, DateTime.now())) {
        // Sharing hours just ended. Refresh the projection so students do not
        // keep seeing the last detected room.
        await _syncPresence();
        return;
      }
      final closest = await scanner.scanOnce();
      if (!_running || closest == null) return;
      // Recheck after the asynchronous scan: sharing may have been paused.
      final latest = await firestoreService.getFacultyLocation(facultyId);
      if (!_running || latest?.isVisible != true) return;
      final updated = await firestoreService.updateFacultyLocation(
        facultyId: facultyId,
        roomId: closest.roomId,
        beaconId: closest.deviceName,
      );
      if (updated) {
        // Keep the student-readable projection in sync with the shared room.
        await _syncPresence(force: true);
      }
      if (updated &&
          (_lastForecast == null ||
              DateTime.now().difference(_lastForecast!).inMinutes >= 2)) {
        await firestoreService.refreshForecast(facultyId);
        _lastForecast = DateTime.now();
      }
    } catch (error) {
      debugPrint('Location update failed: $error');
    } finally {
      _busy = false;
    }
  }

  /// Throttles presence refreshes, except when a room or sharing state changed.
  Future<void> _syncPresence({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastPresenceSync != null &&
        now.difference(_lastPresenceSync!).inMinutes < 2) {
      return;
    }
    try {
      await presenceService.sync(facultyId);
      _lastPresenceSync = now;
    } catch (error) {
      debugPrint('Presence sync failed: $error');
    }
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
