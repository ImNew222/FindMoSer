/// A different room must win consecutive scans before replacing the accepted
/// room. Missing scans clear the candidate so old evidence cannot accumulate.
class BeaconStability {
  String? _accepted;
  String? _candidate;
  int _wins = 0;
  String? observe(String? strongest) {
    if (strongest == null) {
      _candidate = null;
      _wins = 0;
      return null;
    }
    if (strongest == _accepted) {
      _candidate = null;
      _wins = 0;
      return strongest;
    }
    if (strongest == _candidate) {
      _wins++;
    } else {
      _candidate = strongest;
      _wins = 1;
    }
    if (_wins < 2) return null;
    _accepted = strongest;
    _candidate = null;
    _wins = 0;
    return _accepted;
  }
}
