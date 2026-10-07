import 'package:cloud_firestore/cloud_firestore.dart';

enum SyncStatus { pending, synced, failed }

/// Scan evidence is immutable; faculty corrections change the status separately.
class AttendanceRecord {
  final String id, studentId, studentName, facultyId, classId, sessionId;
  final String subject, beaconId, roomId, zoneName, deviceId, date;
  final int rssi, dwellSeconds;
  final DateTime localTimestamp;
  final DateTime? serverTimestamp;
  final SyncStatus syncStatus;
  final String attendanceStatus;
  final bool cached;
  final String? failureReason;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.facultyId,
    required this.classId,
    this.sessionId = '',
    required this.subject,
    required this.beaconId,
    required this.roomId,
    required this.zoneName,
    required this.rssi,
    required this.dwellSeconds,
    required this.deviceId,
    required this.localTimestamp,
    this.serverTimestamp,
    this.syncStatus = SyncStatus.pending,
    required this.date,
    this.attendanceStatus = 'present',
    this.cached = false,
    this.failureReason,
  });

  bool get isSynced =>
      syncStatus == SyncStatus.synced && serverTimestamp != null;

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = (data['serverTimestamp'] as Timestamp?)?.toDate();
    return AttendanceRecord.fromMap(doc.id, {
      ...data,
      'localTimestamp':
          (data['localTimestamp'] as Timestamp).millisecondsSinceEpoch,
      'serverTimestamp': timestamp?.millisecondsSinceEpoch,
      'syncStatus': !doc.metadata.hasPendingWrites && timestamp != null
          ? 'synced'
          : 'pending',
      'cached': doc.metadata.isFromCache,
    });
  }

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> data) =>
      AttendanceRecord(
        id: id,
        studentId: data['studentId'] as String,
        studentName: data['studentName'] as String,
        facultyId: data['facultyId'] as String,
        classId: data['classId'] as String,
        sessionId: data['sessionId'] as String? ?? '',
        subject: data['subject'] as String,
        beaconId: data['beaconId'] as String,
        roomId: data['roomId'] as String,
        zoneName: data['zoneName'] as String,
        rssi: data['rssi'] as int,
        dwellSeconds: data['dwellSeconds'] as int,
        deviceId: data['deviceId'] as String,
        localTimestamp: DateTime.fromMillisecondsSinceEpoch(
          data['localTimestamp'] as int,
        ),
        serverTimestamp: data['serverTimestamp'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                data['serverTimestamp'] as int,
              ),
        syncStatus: SyncStatus.values.firstWhere(
          (s) => s.name == data['syncStatus'],
          orElse: () => SyncStatus.pending,
        ),
        date: data['date'] as String,
        attendanceStatus: data['attendanceStatus'] as String? ?? 'present',
        cached: data['cached'] == true,
        failureReason: data['failureReason'] as String?,
      );

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'facultyId': facultyId,
    'classId': classId,
    'sessionId': sessionId,
    'subject': subject,
    'beaconId': beaconId,
    'roomId': roomId,
    'zoneName': zoneName,
    'rssi': rssi,
    'dwellSeconds': dwellSeconds,
    'deviceId': deviceId,
    'localTimestamp': localTimestamp.millisecondsSinceEpoch,
    'serverTimestamp': serverTimestamp?.millisecondsSinceEpoch,
    'syncStatus': syncStatus.name,
    'date': date,
    'attendanceStatus': attendanceStatus,
    'cached': cached,
    'failureReason': failureReason,
  };

  Map<String, dynamic> toFirestore() => {
    'studentId': studentId,
    'studentName': studentName,
    'facultyId': facultyId,
    'classId': classId,
    'sessionId': sessionId,
    'subject': subject,
    'beaconId': beaconId,
    'roomId': roomId,
    'zoneName': zoneName,
    'rssi': rssi,
    'dwellSeconds': dwellSeconds,
    'deviceId': deviceId,
    'localTimestamp': Timestamp.fromDate(localTimestamp),
    'serverTimestamp': FieldValue.serverTimestamp(),
    'date': date,
    'attendanceStatus': attendanceStatus,
  };

  AttendanceRecord copyWith({
    SyncStatus? syncStatus,
    DateTime? serverTimestamp,
    String? failureReason,
  }) => AttendanceRecord(
    id: id,
    studentId: studentId,
    studentName: studentName,
    facultyId: facultyId,
    classId: classId,
    sessionId: sessionId,
    subject: subject,
    beaconId: beaconId,
    roomId: roomId,
    zoneName: zoneName,
    rssi: rssi,
    dwellSeconds: dwellSeconds,
    deviceId: deviceId,
    localTimestamp: localTimestamp,
    serverTimestamp: serverTimestamp ?? this.serverTimestamp,
    syncStatus: syncStatus ?? this.syncStatus,
    date: date,
    attendanceStatus: attendanceStatus,
    cached: cached,
    failureReason: failureReason,
  );
}
