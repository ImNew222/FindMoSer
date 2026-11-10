import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:findmoser_app/core/app_theme.dart';
import 'package:findmoser_app/core/user_model.dart';
import 'package:findmoser_app/shared/providers/auth_provider.dart';
import 'package:findmoser_app/shared/services/firestore_service.dart';
import 'package:findmoser_app/features/auth/widgets/account_profile_panel.dart';

class RefusedProfileService extends FirestoreService {
  RefusedProfileService() : super(db: FakeFirebaseFirestore());

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'student name rejection exposes permission error instead of claiming success',
    (tester) async {
      const student = AppUser(
        uid: 'student',
        displayName: 'Old Name',
        email: 'student@example.test',
        role: 'student',
        department: 'BSIT',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileStreamProvider.overrideWith(
              (ref) => Stream.value(student),
            ),
            firestoreServiceProvider.overrideWithValue(RefusedProfileService()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: AccountProfilePanel()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit name'));
      await tester.tap(find.text('Edit name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Corrected Name');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('permission-denied'), findsWidgets);
      expect(find.textContaining('Display name updated.'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 700));
      await tester.pumpAndSettle();
      expect(find.text('Old Name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
