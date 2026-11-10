import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/app_constants.dart';
import 'account_access.dart';
import 'device_id_service.dart';

export 'account_access.dart';

/// Authentication with server-verified role and student device registration.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Future<String> Function() _readDeviceId;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Future<String> Function()? readDeviceId,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _readDeviceId = readDeviceId ?? DeviceIdService.getDeviceId;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (result.user == null) {
        throw StateError('Sign-in did not return an account.');
      }
      try {
        await verifyCurrentSession();
      } on SessionUnavailableException {
        // The credential check just succeeded against the server; a dropped
        // connection afterwards must not discard the fresh session. The
        // account gate re-verifies with the server before unlocking.
      }
      return result.user;
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      throw _handleAuthError(e);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  /// A cached profile never grants a new authenticated session. Mismatched
  /// devices retain authentication only for the restricted recovery screen.
  /// Definitive failures (missing profile, unsupported role, device
  /// verification) sign the account out. A pure connectivity failure keeps
  /// the session so queued receipts survive; the account gate retries when
  /// the connection returns, and Firestore rules stay the authority for
  /// everything the client submits while offline.
  Future<AccountAccess> verifyCurrentSession() async {
    final user = currentUser;
    if (user == null) throw StateError('Sign in again to continue.');
    final profileSnapshot = await _serverRead(
      () => _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get(const GetOptions(source: Source.server)),
    );
    final data = profileSnapshot.data();
    if (data == null) {
      await _auth.signOut();
      throw StateError(
        'Account profile is missing. Contact the project team.',
      );
    }
    String? deviceId;
    String? owner;
    if (data['role'] == AppConstants.roleStudent) {
      deviceId = await _readDeviceId();
      final binding = await _serverRead(
        () => _firestore
            .collection('device_bindings')
            .doc(deviceId)
            .get(const GetOptions(source: Source.server)),
      );
      owner = binding.data()?['uid'] as String?;
    }
    try {
      return evaluateAccountAccess(
        uid: user.uid,
        profile: data,
        localDeviceId: deviceId,
        bindingOwner: owner,
      );
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  /// Server-source reads fail with a retryable type when the device is
  /// offline; the connected-device session is never destroyed for that.
  Future<T> _serverRead<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on TimeoutException {
      throw const SessionUnavailableException();
    } on FirebaseException {
      throw const SessionUnavailableException();
    }
  }

  /// Firestore profile and reverse device ownership are committed atomically.
  /// Security rules prohibit overwriting an existing device registration.
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String department,
    String? schoolId,
  }) async {
    if (role != AppConstants.roleStudent && role != AppConstants.roleFaculty) {
      throw ArgumentError('Choose Student or Faculty.');
    }
    if (displayName.trim().isEmpty || displayName.trim().length > 100) {
      throw ArgumentError('Enter a name between 1 and 100 characters.');
    }
    if (department.trim().isEmpty || department.trim().length > 100) {
      throw ArgumentError('Choose a valid department.');
    }
    final deviceId = role == AppConstants.roleStudent
        ? await _readDeviceId()
        : null;
    User? createdUser;
    var profileCommitted = false;
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) throw StateError('Registration failed. Try again.');
      createdUser = user;
      await user.updateDisplayName(displayName.trim());
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection(AppConstants.usersCollection).doc(user.uid),
        {
          'displayName': displayName.trim(),
          'email': email.trim(),
          'role': role,
          'department': department.trim(),
          if (schoolId != null && schoolId.trim().isNotEmpty)
            'schoolId': schoolId.trim(),
          'facultyApproved': false,
          if (deviceId != null) 'deviceId': deviceId,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      if (deviceId != null) {
        batch.set(_firestore.collection('device_bindings').doc(deviceId), {
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      // Auto-link: match roster entries across all classes.
      if (role == AppConstants.roleStudent &&
          schoolId != null &&
          schoolId.trim().isNotEmpty) {
        try {
          final rosterMatches = await _firestore
              .collectionGroup('roster')
              .where('schoolId', isEqualTo: schoolId.trim())
              .get();
          for (final doc in rosterMatches.docs) {
            await doc.reference.update({
              'uid': createdUser.uid,
              'status': 'linked',
            });
          }
        } catch (_) {
          // Auto-link is best-effort; registration succeeds regardless.
        }
      }
      profileCommitted = true;
      return user;
    } catch (error) {
      if (createdUser != null && !profileCommitted) {
        try {
          await createdUser.delete();
        } catch (_) {
          /* Operator may remove an orphan Auth account. */
        }
      }
      await _auth.signOut();
      if (error is FirebaseAuthException) throw _handleAuthError(error);
      if (error is FirebaseException && error.code == 'permission-denied') {
        throw 'Registration was refused. This phone may already belong to a student account, or the current rules need updating. Contact the project team.';
      }
      rethrow;
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// The reset link always goes to the email owner's inbox, so an attacker
  /// who types someone else's address only reaches that person's own mail.
  /// Unknown emails resolve silently so the form cannot be used to probe
  /// which addresses hold accounts; only transport and service errors are
  /// reported, and Firebase rate-limits repeated sends per address.
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Connect to verify your account.';
      default:
        return e.message ?? 'Unable to sign in. Please try again.';
    }
  }
}
