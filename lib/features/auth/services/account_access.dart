/// Network-level failure while verifying a session with the server. The
/// signed-in account stays valid and the gate retries once connectivity
/// returns; Firestore rules remain the authority for anything the client
/// does offline, so no cached unlock weakens evidence checks.
class SessionUnavailableException implements Exception {
  const SessionUnavailableException([
    this.message = 'Connect to the internet and try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Routing decisions must use fresh server data. This gate improves the honest
/// client's behavior; Firestore rules remain the authority for data access.
enum AccountAccess {
  student,
  faculty,
  deviceChangeRequired,
  facultyApprovalRequired,
}

AccountAccess evaluateAccountAccess({
  required String uid,
  required Map<String, dynamic> profile,
  String? localDeviceId,
  String? bindingOwner,
}) {
  if (profile['role'] == 'faculty') {
    return profile['facultyApproved'] == true
        ? AccountAccess.faculty
        : AccountAccess.facultyApprovalRequired;
  }
  if (profile['role'] != 'student') {
    throw StateError(
      'This account has no supported role. Contact the project team.',
    );
  }
  if (profile['deactivated'] == true) {
    throw StateError(
      'Your account has been deactivated. Contact the project team.',
    );
  }
  if (localDeviceId == null || localDeviceId.isEmpty) {
    throw StateError('Device verification is required.');
  }
  if (profile['deviceId'] != localDeviceId || bindingOwner != uid) {
    return AccountAccess.deviceChangeRequired;
  }
  return AccountAccess.student;
}
