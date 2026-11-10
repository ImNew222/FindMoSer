import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/features/auth/services/account_access.dart';

void main() {
  const uid = 'student-one';
  const device = '0123456789abcdef';

  test('student requires both profile and reverse device ownership', () {
    final profile = {'role': 'student', 'deviceId': device};
    AccountAccess check(String? phone, String? owner) => evaluateAccountAccess(
      uid: uid,
      profile: profile,
      localDeviceId: phone,
      bindingOwner: owner,
    );
    expect(check(device, uid), AccountAccess.student);
    expect(check('fedcba9876543210', uid), AccountAccess.deviceChangeRequired);
    expect(check(device, 'someone-else'), AccountAccess.deviceChangeRequired);
    expect(check(device, null), AccountAccess.deviceChangeRequired);
    expect(() => check(null, uid), throwsStateError);
  });

  test('legacy student without a binding requires operator review', () {
    expect(
      evaluateAccountAccess(
        uid: uid,
        profile: {'role': 'student'},
        localDeviceId: device,
      ),
      AccountAccess.deviceChangeRequired,
    );
  });

  test('a deactivated student fails closed before any device check', () {
    expect(
      () => evaluateAccountAccess(
        uid: uid,
        profile: {'role': 'student', 'deviceId': device, 'deactivated': true},
        localDeviceId: device,
        bindingOwner: uid,
      ),
      throwsStateError,
    );
    expect(
      () => evaluateAccountAccess(
        uid: uid,
        profile: {'role': 'student', 'deactivated': true},
        localDeviceId: null,
      ),
      throwsStateError,
    );
    // A non-boolean flag is not an activation signal for deactivation, but a
    // false value leaves the normal routing untouched.
    expect(
      evaluateAccountAccess(
        uid: uid,
        profile: {'role': 'student', 'deviceId': device, 'deactivated': false},
        localDeviceId: device,
        bindingOwner: uid,
      ),
      AccountAccess.student,
    );
  });

  test('requesting the faculty role does not grant faculty access', () {
    for (final approval in [null, false, 'true', 1]) {
      expect(
        evaluateAccountAccess(
          uid: 'faculty-one',
          profile: {'role': 'faculty', 'facultyApproved': approval},
        ),
        AccountAccess.facultyApprovalRequired,
      );
    }
    expect(
      evaluateAccountAccess(
        uid: 'faculty-one',
        profile: {'role': 'faculty', 'facultyApproved': true},
      ),
      AccountAccess.faculty,
    );
  });

  test('unknown and absent roles fail closed', () {
    for (final role in [null, 'admin', 'Student']) {
      expect(
        () => evaluateAccountAccess(
          uid: uid,
          profile: {'role': role},
          localDeviceId: device,
        ),
        throwsStateError,
      );
    }
  });
}
