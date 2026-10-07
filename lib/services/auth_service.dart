import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';
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
      await verifyCurrentSession();
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
  /// Failure to contact the server or verify the device signs the account out.
  Future<AccountAccess> verifyCurrentSession() async {
    try {
      final user = currentUser;
      if (user == null) throw StateError('Sign in again to continue.');
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      final data = doc.data();
      if (data == null) {
        throw StateError(
          'Account profile is missing. Contact the project team.',
        );
      }
      String? deviceId;
      String? owner;
      if (data['role'] == AppConstants.roleStudent) {
        deviceId = await _readDeviceId();
        final binding = await _firestore
            .collection('device_bindings')
            .doc(deviceId)
            .get(const GetOptions(source: Source.server));
        owner = binding.data()?['uid'] as String?;
      }
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

  /// Firestore profile and reverse device ownership are committed atomically.
  /// Security rules prohibit overwriting an existing device registration.
  Future<User?> signUp({
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String department,
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

  /// Kept for callers displaying a role; never use a cached role as permission.
  Future<String?> getUserRole(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    return doc.data()?['role'] as String?;
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
