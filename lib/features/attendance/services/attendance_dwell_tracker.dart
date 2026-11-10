/// Evidence from consecutive advertisements, independent of BLE and Flutter.
/// A timer alone can never complete a dwell: completion needs a fresh reading.
class AttendanceDwellTracker {
  final Duration requiredDwell;
  final Duration maximumGap;
  final int rssiThreshold;
  final String? expectedRoom;

  DateTime? _startedAt;
  DateTime? _lastSeen;
  String? _beaconKey;
  String? _roomId;
  int? _rssi;

  AttendanceDwellTracker({
    this.requiredDwell = const Duration(seconds: 15),
    this.maximumGap = const Duration(seconds: 3),
    this.rssiThreshold = -70,
    this.expectedRoom,
  });

  String? get roomId => _roomId;
  String? get beaconKey => _beaconKey;
  int? get rssi => _rssi;
  bool get hasEvidence => _startedAt != null;
  Duration get verifiedDuration => _startedAt == null || _lastSeen == null
      ? Duration.zero
      : _lastSeen!.difference(_startedAt!);
  bool get complete => verifiedDuration >= requiredDwell;

  /// Returns true if an advertisement changed the evidence. Duplicate, stale,
  /// future and out-of-order advertisements do not advance the dwell.
  bool observe({
    required String beaconKey,
    required String roomId,
    required int rssi,
    required DateTime observedAt,
    required DateTime now,
  }) {
    expire(now);
    if (observedAt.isAfter(now) || now.difference(observedAt) > maximumGap) {
      return false;
    }
    if (_lastSeen != null && !observedAt.isAfter(_lastSeen!)) return false;
    if (beaconKey.isEmpty ||
        roomId.isEmpty ||
        (expectedRoom != null && roomId != expectedRoom) ||
        rssi < rssiThreshold ||
        rssi > 0) {
      reset();
      return true;
    }
    if (_beaconKey != beaconKey ||
        _roomId != roomId ||
        (_lastSeen != null && observedAt.difference(_lastSeen!) > maximumGap)) {
      reset();
    }
    _startedAt ??= observedAt;
    _lastSeen = observedAt;
    _beaconKey = beaconKey;
    _roomId = roomId;
    _rssi = rssi;
    return true;
  }

  /// A lack of new advertisements invalidates progress after the allowed gap.
  /// While waiting for the next reading the displayed progress stays frozen.
  bool expire(DateTime now) {
    if (_lastSeen != null &&
        (now.isBefore(_lastSeen!) || now.difference(_lastSeen!) > maximumGap)) {
      reset();
      return true;
    }
    return false;
  }

  void reset() {
    _startedAt = null;
    _lastSeen = null;
    _beaconKey = null;
    _roomId = null;
    _rssi = null;
  }
}
