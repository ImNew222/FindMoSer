import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/ble_scanner_service.dart';
import '../services/firestore_service.dart';
import '../models/location_model.dart';
import '../config/app_constants.dart';
import 'proximity_provider.dart';
import '../models/user_model.dart';
import '../services/location_policy.dart';

// ─── BLE Scanner Instance ───

final bleScannerProvider = Provider<BleScannerService>((ref) {
  final scanner = BleScannerService();
  ref.onDispose(() => scanner.dispose());
  return scanner;
});

// ─── BLE Availability ───

final bleAvailableProvider = FutureProvider<bool>((ref) async {
  final scanner = ref.watch(bleScannerProvider);
  return scanner.isAvailable;
});

// ─── Detected Beacons Stream ───

final nearbyBeaconsProvider = StreamProvider<List<DetectedBeacon>>((ref) {
  final scanner = ref.watch(bleScannerProvider);
  return scanner.beaconsStream;
});

// ─── Closest Beacon (current room) ───

final currentRoomProvider = Provider<DetectedBeacon?>((ref) {
  final beacons = ref.watch(nearbyBeaconsProvider);
  return beacons.when(
    data: (list) => list.isNotEmpty ? list.first : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

// ─── Faculty Location Streams (for students) ───

/// Stream all faculty locations (real-time)
// A single directory subscription joins one location subscription; no per-card reads.
final locationSnapshotProvider =
    StreamProvider<QuerySnapshot<Map<String, dynamic>>>(
      (ref) => FirebaseFirestore.instance
          .collection(AppConstants.locationsCollection)
          .snapshots(includeMetadataChanges: true),
    );
final locationRecordsProvider = Provider<AsyncValue<List<FacultyLocation>>>(
  (ref) => ref
      .watch(locationSnapshotProvider)
      .whenData((s) => s.docs.map(FacultyLocation.fromFirestore).toList()),
);
final locationCacheProvider = Provider<bool>(
  (ref) =>
      ref.watch(locationSnapshotProvider).value?.metadata.isFromCache ?? true,
);

final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

final allFacultyLocationsProvider =
    Provider<AsyncValue<List<FacultyLocationWithName>>>((ref) {
      ref.watch(
        clockProvider,
      ); // Expire statuses even when Firestore is unchanged.
      final profiles = ref.watch(allFacultyProvider);
      final records = ref.watch(locationRecordsProvider);
      if (profiles.hasError) {
        return AsyncError(profiles.error!, profiles.stackTrace!);
      }
      if (records.hasError) {
        return AsyncError(records.error!, records.stackTrace!);
      }
      if (!profiles.hasValue || !records.hasValue) return const AsyncLoading();
      final byId = {for (final loc in records.value!) loc.facultyId: loc};
      final result = profiles.value!.map((user) {
        final loc = byId[user.uid];
        final shared = LocationPolicy.canShare(user, loc, DateTime.now());
        return FacultyLocationWithName(
          location: shared
              ? loc!
              : FacultyLocation(
                  facultyId: user.uid,
                  currentRoom: 'Not shared',
                  beaconId: '',
                  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
                  isVisible: false,
                  isWithinCampus: false,
                ),
          displayName: user.displayName,
          department: user.department,
          user: user,
        );
      }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
      return AsyncData(result);
    });

/// Faculty location with display name (for UI)
class FacultyLocationWithName {
  final AppUser? user;
  final FacultyLocation location;
  final String displayName;
  final String department;

  const FacultyLocationWithName({
    this.user,
    required this.location,
    required this.displayName,
    required this.department,
  });

  /// Status based on how long ago the location was updated
  FacultyStatus get status {
    if (!location.isVisible || !location.isWithinCampus) {
      return FacultyStatus.offline;
    }
    final diff = DateTime.now().difference(location.timestamp);
    if (diff.isNegative) return FacultyStatus.offline;
    if (diff.inMinutes < 5) return FacultyStatus.online;
    if (diff.inMinutes < 30) return FacultyStatus.recent;
    return FacultyStatus.offline;
  }
}

enum FacultyStatus { online, recent, offline }

// ─── Faculty Location Auto-Updater ───
// Used on faculty dashboard to periodically scan and update Firestore

class FacultyLocationUpdater {
  Timer? _timer;
  bool _running = false;
  bool _busy = false;
  DateTime? _lastForecast;
  final BleScannerService scanner;
  final FirestoreService firestoreService;
  final String facultyId;

  FacultyLocationUpdater({
    required this.scanner,
    required this.firestoreService,
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
      if (!_running ||
          profile == null ||
          location?.isVisible != true ||
          !LocationPolicy.withinHours(profile, DateTime.now())) {
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

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
  }
}
