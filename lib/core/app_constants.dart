/// App-wide constants for FindMoSer
class AppConstants {
  AppConstants._();

  // ─── App Info ───
  static const String appName = 'FindMoSer';
  static const String appTagline = 'Classroom attendance, verified nearby.';
  static const String appVersion = '1.0.0';
  static const String schoolName = 'Cebu Eastern College Inc.';

  // ─── BLE Beacon ───
  static const String blePrefix = 'FindMoSer_';
  static const String bleServiceUUID = '0000FADE-0000-1000-8000-00805F9B34FB';

  // ─── Firestore Collections ───
  static const String usersCollection = 'users';
  static const String roomsCollection = 'rooms';
  static const String locationsCollection = 'locations';
  static const String locationHistoryCollection = 'location_history';
  static const String predictionsCollection = 'predictions';
  static const String attendanceCollection = 'attendance';

  // ─── User Roles ───
  static const String roleStudent = 'student';
  static const String roleFaculty = 'faculty';
  static const String roleAdmin = 'admin';

  // ─── Attendance BLE Settings ───
  /// Initial pilot threshold. Calibrate in every classroom; RSSI does not
  /// prove room boundaries or a fixed distance.
  static const int attendanceRssiThreshold = -70;

  /// How many seconds the student must stay near the beacon
  static const int attendanceDwellSeconds = 15;

  /// Scan duration for attendance check (seconds)
  static const int attendanceScanDurationSec = 8;

  // ─── CEC Departments ───
  static const List<String> departments = [
    'BSIT',
    'BSCS',
    'BSBA',
    'BSA',
    'BSED',
    'BEED',
    'BSCrim',
    'BSHM',
    'ABPolSci',
    'Other',
  ];

  // ─── Timing ───
  static const int splashDurationMs = 2500;
  static const int locationUpdateIntervalSec = 30;
  static const int bleeScanDurationSec = 5;
}
