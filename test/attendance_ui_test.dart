import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:findmoser_app/core/app_theme.dart';
import 'package:findmoser_app/features/attendance/models/attendance_model.dart';
import 'package:findmoser_app/features/attendance/models/attendance_session_model.dart';
import 'package:findmoser_app/core/user_model.dart';
import 'package:findmoser_app/features/attendance/providers/attendance_sessions_provider.dart';
import 'package:findmoser_app/features/attendance/providers/attendance_provider.dart';
import 'package:findmoser_app/shared/providers/auth_provider.dart';
import 'package:findmoser_app/features/attendance/providers/campus_clock_provider.dart';
import 'package:findmoser_app/features/attendance/widgets/attendance_session_card.dart';
import 'package:findmoser_app/features/attendance/screens/student/student_dashboard.dart';
import 'package:findmoser_app/features/attendance/models/schedule_model.dart';
import 'package:findmoser_app/features/attendance/widgets/session_enrollment_sheet.dart';
import 'package:findmoser_app/features/faculty/screens/attendance_roster_screen.dart';
import 'package:findmoser_app/features/attendance/services/attendance_session_service.dart';
import 'package:findmoser_app/features/attendance/widgets/attendance_card.dart';
import 'package:findmoser_app/features/attendance/widgets/class_picker_sheet.dart';

AttendanceRecord receipt({
  SyncStatus status = SyncStatus.pending,
  bool cached = false,
}) => AttendanceRecord(
  id: 'session-student',
  studentId: 'student',
  studentName: 'Ana Cruz',
  facultyId: 'faculty',
  classId: 'class',
  sessionId: 'session',
  subject: 'Mobile application development',
  beaconId: 'FindMoSer_Room305',
  roomId: 'Room305',
  zoneName: 'IT',
  rssi: -55,
  dwellSeconds: 15,
  deviceId: 'device',
  localTimestamp: DateTime.utc(2026, 10, 7, 1),
  serverTimestamp: status == SyncStatus.synced
      ? DateTime.utc(2026, 10, 7, 1, 1)
      : null,
  syncStatus: status,
  date: '2026-10-07',
  cached: cached,
  failureReason: status == SyncStatus.failed
      ? 'The session closed before upload.'
      : null,
);

AttendanceSession session({String id = 'session', String status = 'open'}) =>
    AttendanceSession(
      id: id,
      facultyId: 'faculty',
      classId: 'class',
      subject: 'Programming $id',
      roomId: 'Room305',
      date: '2026-10-07',
      openedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      closesAt: DateTime.now().add(const Duration(minutes: 10)),
      status: status,
      enrolledStudentIds: ['student', 'student2'],
    );

class _StudentDirectory extends AttendanceSessionService {
  _StudentDirectory() : super(db: FakeFirebaseFirestore());
  @override
  Stream<List<AppUser>> streamStudents() => Stream.value([
    const AppUser(
      uid: 'student',
      displayName: 'Ana Cruz',
      email: 'ana@example.test',
      role: 'student',
      department: 'BSIT',
    ),
    const AppUser(
      uid: 'student2',
      displayName: 'Ben Reyes',
      email: 'ben@example.test',
      role: 'student',
      department: 'BSIT',
    ),
  ]);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final loader = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await loader.load();
  });

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final output = Platform.environment['PREVIEW_OUTPUT'];
    if (output == null) return;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('receipts distinguish pending, confirmed cached, and rejection', (
    tester,
  ) async {
    phone(tester);
    Future<void> show(AttendanceRecord record) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(child: AttendanceCard(record: record)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(receipt());
    expect(find.text('Pending upload'), findsOneWidget);
    expect(find.text('Confirmed'), findsNothing);
    await show(receipt(status: SyncStatus.synced, cached: true));
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Saved copy'), findsOneWidget);
    await show(receipt(status: SyncStatus.failed));
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('The session closed before upload.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'class picker offers open enrollment sessions and separate diagnostic',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentSessionsProvider.overrideWith(
              (ref) => Stream.value([
                session(id: 'open'),
                session(id: 'closed', status: 'closed'),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showClassPickerSheet(context),
                    child: const Text('Choose'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(find.text('Programming open'), findsOneWidget);
      expect(find.text('Programming closed'), findsNothing);
      expect(find.text('Test beacon • no attendance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'roster updates live, supports search, and does not label missing receipts absent',
    (tester) async {
      phone(tester);
      final key = GlobalKey();
      final stream = StreamController<List<AttendanceRecord>>();
      addTearDown(stream.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionServiceProvider.overrideWithValue(_StudentDirectory()),
            facultySessionsProvider.overrideWith(
              (ref) => Stream.value([session(status: 'closed')]),
            ),
            sessionRecordsProvider(
              'session',
            ).overrideWith((ref) => stream.stream),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: RepaintBoundary(
              key: key,
              child: AttendanceRosterScreen(session: session(status: 'closed')),
            ),
          ),
        ),
      );
      stream.add([]);
      await tester.pumpAndSettle();
      expect(find.text('2 without receipt'), findsOneWidget);
      expect(find.text('0 marked absent'), findsOneWidget);
      stream.add([receipt(status: SyncStatus.synced)]);
      await tester.pumpAndSettle();
      expect(find.text('1 present'), findsOneWidget);
      expect(find.text('1 without receipt'), findsOneWidget);
      await capture(tester, key, 'faculty-roster');
      await tester.enterText(find.byType(TextField), 'Ben');
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('Ben Reyes'), findsOneWidget);
      expect(find.text('Ana Cruz'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('student dashboard keeps attendance primary at phone size', (
    tester,
  ) async {
    phone(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileStreamProvider.overrideWith(
            (ref) => Stream.value(
              const AppUser(
                uid: 'student',
                displayName: 'Ana Cruz',
                email: 'ana@example.test',
                role: 'student',
                department: 'BSIT',
              ),
            ),
          ),
          studentSessionsProvider.overrideWith(
            (ref) => Stream.value([session()]),
          ),
          studentAttendanceTodayProvider.overrideWith(
            (ref) => Stream.value([receipt(status: SyncStatus.synced)]),
          ),
        ],
        child: RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const StudentDashboard(),
          ),
        ),
      ),
    );
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pumpAndSettle();
    expect(find.text('Open classes'), findsOneWidget);
    expect(find.text('Find faculty'), findsNothing);
    expect(find.text('Faculty assistant'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'student-home');
  });

  testWidgets(
    'enrollment cannot be cleared before loading and fits with keyboard',
    (tester) async {
      phone(tester);
      final enrollments = StreamController<List<String>>();
      addTearDown(enrollments.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionServiceProvider.overrideWithValue(
              _EnrollmentDirectory(enrollments.stream),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SessionEnrollmentSheet(
                facultyId: 'faculty',
                schedule: ClassSchedule(
                  id: 'class',
                  dayOfWeek: 'Thursday',
                  startTime: '08:00',
                  endTime: '09:00',
                  roomName: 'Room305',
                  subject: 'Programming',
                ),
                openSession: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final save = find.widgetWithText(FilledButton, 'Save enrollment');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      enrollments.add(['student']);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('session status changes at expiry without a Firestore update', (
    tester,
  ) async {
    final clock = StreamController<DateTime>();
    addTearDown(clock.close);
    final active = session();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [campusClockProvider.overrideWith((ref) => clock.stream)],
        child: MaterialApp(
          home: Scaffold(body: AttendanceSessionCard(session: active)),
        ),
      ),
    );
    clock.add(active.closesAt.subtract(const Duration(seconds: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    clock.add(active.closesAt);
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('expired session disappears from picker on clock tick', (
    tester,
  ) async {
    phone(tester);
    final clock = StreamController<DateTime>();
    addTearDown(clock.close);
    final active = session();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          campusClockProvider.overrideWith((ref) => clock.stream),
          studentSessionsProvider.overrideWith((ref) => Stream.value([active])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showClassPickerSheet(context),
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      ),
    );
    clock.add(active.closesAt.subtract(const Duration(seconds: 1)));
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    expect(find.text('Programming session'), findsOneWidget);
    clock.add(active.closesAt);
    await tester.pumpAndSettle();
    expect(find.text('Programming session'), findsNothing);
    expect(find.textContaining('No open sessions.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('campus date only changes at Cebu midnight', () async {
    final clock = StreamController<DateTime>();
    final container = ProviderContainer(
      overrides: [campusClockProvider.overrideWith((ref) => clock.stream)],
    );
    final changes = <String>[];
    final subscription = container.listen(
      campusDateProvider,
      (_, value) => changes.add(value),
    );
    clock.add(DateTime.utc(2026, 10, 7, 15, 59, 30));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    changes.clear();
    clock.add(DateTime.utc(2026, 10, 7, 15, 59, 59));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(changes, isEmpty);
    clock.add(DateTime.utc(2026, 10, 7, 16));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(changes, ['2026-10-08']);
    subscription.close();
    container.dispose();
    await clock.close();
  });
}

class _EnrollmentDirectory extends _StudentDirectory {
  final Stream<List<String>> enrollments;
  _EnrollmentDirectory(this.enrollments);
  @override
  Stream<List<String>> streamEnrollment(String facultyId, String classId) =>
      enrollments;
}
