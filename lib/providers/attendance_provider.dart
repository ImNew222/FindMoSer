import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_constants.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/attendance_dwell_tracker.dart';
import '../services/device_id_service.dart';
import 'auth_provider.dart';

// ─── Service Providers ───

final attendanceServiceProvider = Provider<AttendanceService>(
  (ref) => AttendanceService(),
);

// ─── Student's Today Attendance Stream ───

final studentAttendanceTodayProvider = StreamProvider<List<AttendanceRecord>>((
  ref,
) {
  final authState = ref.watch(authStateProvider);
  final service = ref.read(attendanceServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service.streamStudentAttendanceToday(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ─── Faculty's Today Attendance Stream ───

final facultyAttendanceTodayProvider = StreamProvider<List<AttendanceRecord>>((
  ref,
) {
  final authState = ref.watch(authStateProvider);
  final service = ref.read(attendanceServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service.streamClassAttendanceToday(facultyId: user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

/// Pending means the server has not acknowledged the submission. Diagnostic
/// completion is separate from attendance confirmation and never writes data.
enum AttendanceScanPhase {
  idle,
  scanning,
  dwelling,
  recording,
  pending,
  success,
  diagnostic,
  failed,
}

class AttendanceScanState {
  final AttendanceScanPhase phase;
  final String? beaconName;
  final String? roomId;
  final int? rssi;
  final int dwellProgress;
  final int dwellRequired;
  final String? errorMessage;
  final String? recordId;
  final bool diagnosticOnly;
  final String? subject;
  final String? sessionDate;
  final DateTime? submittedAt;

  const AttendanceScanState({
    this.phase = AttendanceScanPhase.idle,
    this.beaconName,
    this.roomId,
    this.rssi,
    this.dwellProgress = 0,
    this.dwellRequired = AppConstants.attendanceDwellSeconds,
    this.errorMessage,
    this.recordId,
    this.diagnosticOnly = false,
    this.subject,
    this.sessionDate,
    this.submittedAt,
  });

  bool get isIdle => phase == AttendanceScanPhase.idle;
  bool get isScanning => phase == AttendanceScanPhase.scanning;
  bool get isDwelling => phase == AttendanceScanPhase.dwelling;
  bool get isSuccess => phase == AttendanceScanPhase.success;
  bool get isFailed => phase == AttendanceScanPhase.failed;
  bool get isSubmitting =>
      phase == AttendanceScanPhase.recording ||
      phase == AttendanceScanPhase.pending;
  bool get isBusy => isScanning || isDwelling || isSubmitting;
  double get dwellFraction =>
      dwellRequired > 0 ? (dwellProgress / dwellRequired).clamp(0.0, 1.0) : 0;

  AttendanceScanState copyWith({
    AttendanceScanPhase? phase,
    String? beaconName,
    String? roomId,
    int? rssi,
    int? dwellProgress,
    String? errorMessage,
    String? recordId,
    DateTime? submittedAt,
  }) => AttendanceScanState(
    phase: phase ?? this.phase,
    beaconName: beaconName ?? this.beaconName,
    roomId: roomId ?? this.roomId,
    rssi: rssi ?? this.rssi,
    dwellProgress: dwellProgress ?? this.dwellProgress,
    dwellRequired: dwellRequired,
    errorMessage: errorMessage,
    recordId: recordId ?? this.recordId,
    diagnosticOnly: diagnosticOnly,
    subject: subject,
    sessionDate: sessionDate,
    submittedAt: submittedAt ?? this.submittedAt,
  );
}

class AttendanceScanNotifier extends StateNotifier<AttendanceScanState> {
  final AttendanceService _attendanceService;
  final Ref _ref;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterSubscription;
  Timer? _freshnessTimer;
  Timer? _deadlineTimer;
  Timer? _pendingTimer;
  // BLE scanning is process-wide, including across scanner route instances.
  static Future<void> _cleanup = Future.value();
  Future<void>? _startOperation;
  AttendanceDwellTracker? _tracker;
  bool _disposed = false;
  bool _bleActive = false;
  int _generation = 0;
  String? _sessionId;
  String? _facultyId;
  String? _classId;
  String? _subject;
  String? _deviceId;
  String? _studentId;
  String? _studentName;
  DateTime? _closesAt;

  AttendanceScanNotifier(this._attendanceService, this._ref)
    : super(const AttendanceScanState());

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> startScan({
    required String facultyId,
    required String classId,
    required String subject,
    String? expectedRoom,
    String? sessionId,
  }) async {
    if (_disposed || state.isBusy) return;
    final generation = ++_generation;
    // A missing session is an explicit diagnostic. An empty ID is invalid,
    // never a way to bypass session verification.
    _studentId = null;
    _studentName = null;
    _deviceId = null;
    _sessionId = sessionId;
    _facultyId = facultyId;
    _classId = classId;
    _subject = subject;
    _closesAt = null;
    state = AttendanceScanState(
      phase: AttendanceScanPhase.scanning,
      diagnosticOnly: sessionId == null,
      subject: subject,
      roomId: expectedRoom,
    );
    try {
      await _cleanup;
      if (!_current(generation)) return;
      if (sessionId != null) {
        final user = _ref.read(authStateProvider).value;
        if (user == null) {
          throw StateError('Sign in before checking attendance.');
        }
        _studentId = user.uid;
        _deviceId = await DeviceIdService.getDeviceId();
        if (!_current(generation)) return;
        final session = await _attendanceService
            .preflightSession(
              sessionId: sessionId,
              studentId: user.uid,
              deviceId: _deviceId!,
            )
            .timeout(const Duration(seconds: 12));
        if (!_current(generation)) return;
        // AttendanceService keeps the authoritative profile from preflight;
        // the legacy studentName argument is not used to authorize this write.
        _studentName = '';
        _facultyId = session.facultyId;
        _classId = session.classId;
        _subject = session.subject;
        _closesAt = session.closesAt;
        expectedRoom = session.roomId;
        state = AttendanceScanState(
          phase: AttendanceScanPhase.scanning,
          subject: session.subject,
          roomId: session.roomId,
          sessionDate: session.date,
        );
      }
      _tracker = AttendanceDwellTracker(
        requiredDwell: const Duration(
          seconds: AppConstants.attendanceDwellSeconds,
        ),
        rssiThreshold: AppConstants.attendanceRssiThreshold,
        expectedRoom: expectedRoom,
      );
      await _performScan(generation);
    } on TimeoutException {
      if (_current(generation)) {
        _fail(
          'Connection timed out. Check internet and Bluetooth, then retry.',
        );
      }
    } catch (error) {
      if (_current(generation)) _fail(_message(error));
    }
  }

  Future<void> _performScan(int generation) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw StateError('Use the Android app for classroom Bluetooth scanning.');
    }
    final supported = await FlutterBluePlus.isSupported.timeout(
      const Duration(seconds: 5),
    );
    if (!_current(generation)) return;
    if (!supported) {
      throw StateError('This phone does not support Bluetooth scanning.');
    }
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    if (!_current(generation)) return;
    if (permissions.values.any((permission) => !permission.isGranted)) {
      throw StateError(
        'Allow Bluetooth and location permissions in device settings, then retry.',
      );
    }
    final adapter = await FlutterBluePlus.adapterState
        .where((value) => value != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5));
    if (!_current(generation)) return;
    if (adapter != BluetoothAdapterState.on) {
      throw StateError('Turn on Bluetooth, then retry.');
    }

    final startedAt = DateTime.now();
    final seen = <String, DateTime>{};
    _bleActive = true;
    _adapterSubscription = FlutterBluePlus.adapterState.listen((adapter) {
      if (_current(generation) &&
          _bleActive &&
          adapter != BluetoothAdapterState.on) {
        _fail('Bluetooth was turned off. Turn it on and scan again.');
      }
    });
    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        if (!_current(generation) || !_bleActive || state.isSubmitting) return;
        final now = DateTime.now();
        final fresh = results.where((result) {
          final key = result.device.remoteId.str;
          final name = result.advertisementData.advName;
          final previous = seen[key];
          if (!name.startsWith(AppConstants.blePrefix) ||
              result.timeStamp.isBefore(startedAt) ||
              result.timeStamp.isAfter(now) ||
              now.difference(result.timeStamp) > const Duration(seconds: 3) ||
              (previous != null && !result.timeStamp.isAfter(previous))) {
            return false;
          }
          seen[key] = result.timeStamp;
          return true;
        }).toList();
        final tracker = _tracker!;
        final candidates = fresh.where((result) {
          final room = result.advertisementData.advName.substring(
            AppConstants.blePrefix.length,
          );
          return room.isNotEmpty &&
              (tracker.expectedRoom == null || room == tracker.expectedRoom);
        }).toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
        // Neighboring rooms can advertise between valid target advertisements.
        // They never extend the target dwell; the freshness timer expires it.
        if (candidates.isEmpty) {
          if (fresh.isNotEmpty && !tracker.hasEvidence) {
            state = state.copyWith(
              errorMessage:
                  'Another room was detected. Move to the selected classroom.',
            );
          }
          return;
        }
        final matching = candidates.where(
          (r) => r.device.remoteId.str == tracker.beaconKey,
        );
        final reading = matching.isEmpty ? candidates.first : matching.first;
        tracker.observe(
          beaconKey: reading.device.remoteId.str,
          roomId: reading.advertisementData.advName.substring(
            AppConstants.blePrefix.length,
          ),
          rssi: reading.rssi,
          observedAt: reading.timeStamp,
          now: now,
        );
        if (!tracker.hasEvidence) {
          _showSearching('Signal weakened. The 15-second check has restarted.');
          return;
        }
        state = state.copyWith(
          phase: AttendanceScanPhase.dwelling,
          beaconName: reading.advertisementData.advName,
          roomId: tracker.roomId,
          rssi: tracker.rssi,
          dwellProgress: tracker.verifiedDuration.inSeconds.clamp(
            0,
            AppConstants.attendanceDwellSeconds,
          ),
        );
        if (tracker.complete) unawaited(_completeDwell(generation));
      },
      onError: (Object error) {
        if (_current(generation) && _bleActive) {
          _fail('Bluetooth scan failed: ${_message(error)}');
        }
      },
    );
    _freshnessTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_current(generation) || !_bleActive) return;
      if (_closesAt != null && !DateTime.now().isBefore(_closesAt!)) {
        _fail(
          'This attendance session has closed. Ask your faculty member for help.',
        );
      } else if (_tracker!.expire(DateTime.now())) {
        _showSearching(
          'Beacon readings stopped. Progress reset; stay in the selected classroom.',
        );
      }
    });
    _deadlineTimer = Timer(const Duration(seconds: 75), () {
      if (_current(generation) && _bleActive) {
        _fail(
          'Continuous proximity could not be verified. Check the room and try again.',
        );
      }
    });
    _startOperation = FlutterBluePlus.startScan(
      continuousUpdates: true,
      // Classroom detection derives location from BLE, so request the matching
      // fine-location permission instead of asserting neverForLocation.
      androidUsesFineLocation: true,
    ).timeout(const Duration(seconds: 8));
    await _startOperation;
    // Cancellation has already queued a stop after this start completes. A
    // stale continuation must never stop a newer scan or its subscriptions.
    if (_current(generation) && !_bleActive) _queueStopBle();
  }

  void _showSearching(String message) {
    state = AttendanceScanState(
      phase: AttendanceScanPhase.scanning,
      diagnosticOnly: state.diagnosticOnly,
      roomId: _tracker?.expectedRoom,
      subject: state.subject,
      sessionDate: state.sessionDate,
      errorMessage: message,
    );
  }

  Future<void> _completeDwell(int generation) async {
    if (!_current(generation) || !_bleActive) return;
    // Latch before stopping BLE so another advertisement cannot submit twice.
    _bleActive = false;
    final evidence = state;
    _queueStopBle();
    if (_sessionId == null) {
      state = state.copyWith(phase: AttendanceScanPhase.diagnostic);
      return;
    }
    state = state.copyWith(
      phase: AttendanceScanPhase.recording,
      submittedAt: DateTime.now(),
    );
    _pendingTimer = Timer(const Duration(seconds: 8), () {
      if (_current(generation) &&
          state.phase == AttendanceScanPhase.recording) {
        state = state.copyWith(phase: AttendanceScanPhase.pending);
      }
    });
    try {
      final currentUser = _ref.read(authStateProvider).value;
      if (currentUser == null || currentUser.uid != _studentId) {
        throw StateError(
          'Your sign-in changed. Sign in again before checking attendance.',
        );
      }
      // This future is deliberately not timed out or cancelled: the service
      // retains pending/rejected records after this screen is closed.
      final id = await _attendanceService.recordAttendance(
        sessionId: _sessionId!,
        studentId: _studentId!,
        studentName: _studentName!,
        facultyId: _facultyId!,
        classId: _classId!,
        subject: _subject!,
        beaconId: evidence.beaconName!,
        roomId: evidence.roomId!,
        zoneName: evidence.roomId!,
        rssi: evidence.rssi!,
        dwellSeconds: evidence.dwellProgress,
        deviceId: _deviceId!,
      );
      if (!_current(generation)) return;
      _pendingTimer?.cancel();
      state = state.copyWith(phase: AttendanceScanPhase.success, recordId: id);
    } on AttendancePendingException {
      if (!_current(generation)) return;
      _pendingTimer?.cancel();
      state = state.copyWith(
        phase: AttendanceScanPhase.pending,
        errorMessage:
            'Connection interrupted. Your receipt is pending. Reconnect and check Attendance for confirmation; do not scan again.',
      );
    } catch (error) {
      if (_current(generation)) {
        _fail('Attendance was not confirmed. ${_message(error)}');
      }
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Bad state: ', '');

  void _fail(String message) {
    if (_disposed) return;
    _pendingTimer?.cancel();
    _queueStopBle();
    _tracker?.reset();
    state = state.copyWith(
      phase: AttendanceScanPhase.failed,
      errorMessage: message,
    );
  }

  void _queueStopBle() {
    _bleActive = false;
    _freshnessTimer?.cancel();
    _deadlineTimer?.cancel();
    final scanSubscription = _scanSubscription;
    final adapterSubscription = _adapterSubscription;
    final startOperation = _startOperation;
    _scanSubscription = null;
    _adapterSubscription = null;
    _startOperation = null;
    if (scanSubscription == null &&
        adapterSubscription == null &&
        startOperation == null) {
      return;
    }
    _cleanup = _cleanup.then((_) async {
      try {
        await startOperation;
      } catch (_) {
        // A failed/timed-out start still needs a native stop attempt.
      }
      try {
        await scanSubscription?.cancel();
        await adapterSubscription?.cancel();
      } catch (_) {
        // Failed native stream cancellation must not block a later retry.
      }
      if (!kIsWeb) {
        try {
          await FlutterBluePlus.stopScan().timeout(const Duration(seconds: 5));
        } catch (_) {
          // Cleanup errors must not crash route disposal or mask the scan error.
        }
      }
    });
  }

  /// Backgrounding invalidates unfinished proximity checks, but a submitted
  /// request remains in the service outbox until the server accepts/rejects it.
  void onBackground() {
    if (_disposed || state.isSubmitting || !state.isBusy) return;
    ++_generation;
    _fail(
      'Scan paused. Return to the classroom and restart the proximity check.',
    );
  }

  /// Cancels evidence collection/detaches UI; it cannot undo a submitted write.
  void cancel() {
    if (_disposed) return;
    ++_generation;
    _pendingTimer?.cancel();
    _tracker?.reset();
    _queueStopBle();
    state = const AttendanceScanState();
  }

  void reset() => cancel();

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _pendingTimer?.cancel();
    _tracker?.reset();
    _queueStopBle();
    super.dispose();
  }
}

final attendanceScanProvider =
    StateNotifierProvider.autoDispose<
      AttendanceScanNotifier,
      AttendanceScanState
    >((ref) {
      return AttendanceScanNotifier(ref.watch(attendanceServiceProvider), ref);
    });
