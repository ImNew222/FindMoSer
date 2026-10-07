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
  if (localDeviceId == null || localDeviceId.isEmpty) {
    throw StateError('Device verification is required.');
  }
  if (profile['deviceId'] != localDeviceId || bindingOwner != uid) {
    return AccountAccess.deviceChangeRequired;
  }
  return AccountAccess.student;
}
