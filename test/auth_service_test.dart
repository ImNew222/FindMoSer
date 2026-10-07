import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:findmoser_app/services/auth_service.dart';
import 'package:findmoser_app/services/device_id_service.dart';

class _User extends Fake implements User {
  @override
  final String uid;
  _User(this.uid);
  @override
  Future<void> updateDisplayName(String? displayName) async {}
  @override
  Future<void> delete() async {}
}

class _Credential extends Fake implements UserCredential {
  @override
  final User user;
  _Credential(this.user);
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  int registrations = 0;
  int signOuts = 0;
  _Auth([this.currentUser]);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registrations++;
    currentUser = _User('new-user');
    return _Credential(currentUser!);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _Credential(currentUser ??= _User('student-one'));

  @override
  Future<void> signOut() async {
    signOuts++;
    currentUser = null;
  }
}

class _UnavailableFirestore extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
  }
}

void main() {
  const phone = '0123456789abcdef';

  test(
    'student registration commits profile and reverse ownership together',
    () async {
      final db = FakeFirebaseFirestore();
      final auth = _Auth();
      final service = AuthService(
        auth: auth,
        firestore: db,
        readDeviceId: () async => phone,
      );
      final user = await service.signUp(
        email: ' student@school.edu ',
        password: 'secret123',
        displayName: ' Student One ',
        role: 'student',
        department: ' BSIT ',
      );
      final profile = (await db.collection('users').doc(user!.uid).get())
          .data()!;
      final binding = (await db.collection('device_bindings').doc(phone).get())
          .data()!;
      expect(profile['displayName'], 'Student One');
      expect(profile['email'], 'student@school.edu');
      expect(profile['deviceId'], phone);
      expect(profile['department'], 'BSIT');
      expect(profile['facultyApproved'], false);
      expect(binding['uid'], user.uid);
      expect(binding['createdAt'], isA<Timestamp>());
      expect(await service.verifyCurrentSession(), AccountAccess.student);
    },
  );

  test(
    'faculty registration stays restricted until trusted approval',
    () async {
      final db = FakeFirebaseFirestore();
      final auth = _Auth();
      final service = AuthService(
        auth: auth,
        firestore: db,
        readDeviceId: () async {
          fail('Faculty registration must not bind a student device.');
        },
      );
      final user = await service.signUp(
        email: 'faculty@school.edu',
        password: 'secret123',
        displayName: 'Faculty One',
        role: 'faculty',
        department: 'BSIT',
      );
      expect((await db.collection('device_bindings').get()).docs, isEmpty);
      expect(
        await service.verifyCurrentSession(),
        AccountAccess.facultyApprovalRequired,
      );
      await db.collection('users').doc(user!.uid).update({
        'facultyApproved': true,
      });
      expect(await service.verifyCurrentSession(), AccountAccess.faculty);
    },
  );

  test(
    'unavailable device aborts registration before creating an auth account',
    () async {
      final auth = _Auth();
      final service = AuthService(
        auth: auth,
        firestore: FakeFirebaseFirestore(),
        readDeviceId: () async =>
            throw const DeviceIdUnavailable('unavailable'),
      );
      await expectLater(
        service.signUp(
          email: 'student@school.edu',
          password: 'secret123',
          displayName: 'Student',
          role: 'student',
          department: 'BSIT',
        ),
        throwsA(isA<DeviceIdUnavailable>()),
      );
      expect(auth.registrations, 0);
    },
  );

  test(
    'wrong phone keeps authentication only for restricted recovery',
    () async {
      final db = FakeFirebaseFirestore();
      final auth = _Auth(_User('student-one'));
      await db.collection('users').doc('student-one').set({
        'role': 'student',
        'deviceId': 'fedcba9876543210',
      });
      final service = AuthService(
        auth: auth,
        firestore: db,
        readDeviceId: () async => phone,
      );
      await service.signIn(email: 'student@school.edu', password: 'secret123');
      expect(
        await service.verifyCurrentSession(),
        AccountAccess.deviceChangeRequired,
      );
      expect(auth.currentUser?.uid, 'student-one');
      expect(auth.signOuts, 0);
    },
  );

  test(
    'profile or server verification failure signs the account out',
    () async {
      for (final db in [FakeFirebaseFirestore(), _UnavailableFirestore()]) {
        final auth = _Auth(_User('student-one'));
        final service = AuthService(
          auth: auth,
          firestore: db,
          readDeviceId: () async => phone,
        );
        await expectLater(service.verifyCurrentSession(), throwsA(anything));
        expect(auth.currentUser, isNull);
        expect(auth.signOuts, 1);
      }
    },
  );
}
