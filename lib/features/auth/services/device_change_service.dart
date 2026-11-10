import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'device_id_service.dart';

/// Students can request a replacement; only a trusted operator changes binding.
class DeviceChangeService {
  final FirebaseFirestore _db;
  final String? Function() _currentUid;
  final Future<String> Function() _readDeviceId;

  DeviceChangeService({
    FirebaseFirestore? db,
    String? Function()? currentUid,
    Future<String> Function()? readDeviceId,
  }) : _db = db ?? FirebaseFirestore.instance,
       _currentUid =
           currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _readDeviceId = readDeviceId ?? DeviceIdService.getDeviceId;

  Future<Map<String, dynamic>?> currentRequest() async {
    final uid = _requireUid();
    final result = await _db
        .collection('device_change_requests')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    return result.data();
  }

  Future<void> requestChange(String reason) async {
    final uid = _requireUid();
    final explanation = reason.trim();
    if (explanation.length < 10 || explanation.length > 500) {
      throw ArgumentError('Explain the device change in 10–500 characters.');
    }
    final deviceId = await _readDeviceId();
    final ref = _db.collection('device_change_requests').doc(uid);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.data()?['status'] == 'pending') {
        throw StateError(
          'A request is already pending. Contact the project team to change it.',
        );
      }
      transaction.set(ref, {
        'studentId': uid,
        'newDeviceId': deviceId,
        'reason': explanation,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _requireUid() {
    final uid = _currentUid();
    if (uid == null) {
      throw StateError('Sign in before requesting a device change.');
    }
    return uid;
  }
}
