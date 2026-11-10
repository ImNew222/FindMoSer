import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:findmoser_app/features/attendance/services/attendance_service.dart';
import 'package:findmoser_app/features/attendance/screens/student/attendance_scan_screen.dart';
import 'package:findmoser_app/features/attendance/providers/attendance_provider.dart';
import 'package:findmoser_app/features/attendance/widgets/attendance_scan_widgets.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> showStatus(
    WidgetTester tester,
    AttendanceScanState state,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttendanceScanStatusText(scan: state, subject: 'IT 101'),
        ),
      ),
    );
  }

  testWidgets('pending submission never presents attendance as confirmed', (
    tester,
  ) async {
    await showStatus(
      tester,
      const AttendanceScanState(phase: AttendanceScanPhase.pending),
    );
    expect(find.text('Pending confirmation'), findsOneWidget);
    expect(find.text('Attendance confirmed'), findsNothing);
    expect(find.textContaining('has not confirmed'), findsOneWidget);
  });

  testWidgets('transport interruption preserves a pending receipt message', (
    tester,
  ) async {
    await showStatus(
      tester,
      const AttendanceScanState(
        phase: AttendanceScanPhase.pending,
        errorMessage:
            'Connection interrupted. Your receipt is pending. Reconnect and check Attendance for confirmation; do not scan again.',
      ),
    );
    expect(find.text('Pending confirmation'), findsOneWidget);
    expect(
      find.textContaining('Reconnect and check Attendance'),
      findsOneWidget,
    );
    expect(find.text('Scan failed'), findsNothing);
  });

  testWidgets('diagnostics explicitly state no attendance was submitted', (
    tester,
  ) async {
    await showStatus(
      tester,
      const AttendanceScanState(
        phase: AttendanceScanPhase.diagnostic,
        diagnosticOnly: true,
        roomId: 'Room305',
      ),
    );
    expect(find.text('Beacon test complete'), findsOneWidget);
    expect(find.textContaining('No attendance was submitted.'), findsOneWidget);
    expect(find.text('Attendance confirmed'), findsNothing);
  });

  testWidgets('server-confirmed state is the only receipt success wording', (
    tester,
  ) async {
    await showStatus(
      tester,
      const AttendanceScanState(phase: AttendanceScanPhase.success),
    );
    expect(find.text('Attendance confirmed'), findsOneWidget);
    expect(find.textContaining('server accepted'), findsOneWidget);
  });

  testWidgets(
    'pending action closes the screen without offering duplicate submission',
    (tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceScanActions(
              scan: const AttendanceScanState(
                phase: AttendanceScanPhase.pending,
              ),
              onRetry: () => fail('Pending writes must not offer retry'),
              onDone: () => fail('Pending writes must not offer Done'),
              onCancel: () => closed = true,
            ),
          ),
        ),
      );
      expect(find.text('Try Again'), findsNothing);
      expect(find.text('Done'), findsNothing);
      await tester.tap(find.text('Close • check status in Attendance'));
      expect(closed, isTrue);
    },
  );

  testWidgets(
    'small-screen pending flow scrolls and closing disposes the scanner',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late _PendingScanner scanner;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceScanProvider.overrideWith(
              (ref) => scanner = _PendingScanner(ref),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('Open scanner'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AttendanceScanScreen(
                        facultyId: 'faculty',
                        classId: 'class',
                        subject: 'Introduction to Information Technology',
                        facultyName: 'Faculty session',
                        sessionId: 'session',
                        roomName: 'Room305',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();
      expect(find.text('Pending confirmation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close; submission continues'));
      await tester.pumpAndSettle();
      expect(find.text('Open scanner'), findsOneWidget);
      expect(scanner.wasDisposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final phase in [
    AttendanceScanPhase.dwelling,
    AttendanceScanPhase.pending,
  ]) {
    testWidgets('backgrounding $phase preserves only submitted evidence', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceScanProvider.overrideWith(
              (ref) => _PendingScanner(ref, initialPhase: phase),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const AttendanceScanScreen(
              facultyId: 'faculty',
              classId: 'class',
              subject: 'IT 101',
              facultyName: 'Faculty',
              sessionId: 'session',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      if (phase == AttendanceScanPhase.dwelling) {
        expect(find.text('Scan failed'), findsOneWidget);
        expect(find.textContaining('Scan paused.'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);
      } else {
        expect(find.text('Pending confirmation'), findsOneWidget);
        expect(find.text('Try Again'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _PendingScanner extends AttendanceScanNotifier {
  bool wasDisposed = false;
  final AttendanceScanPhase initialPhase;
  _PendingScanner(Ref ref, {this.initialPhase = AttendanceScanPhase.pending})
    : super(
        AttendanceService(db: FakeFirebaseFirestore(), currentUid: () => null),
        ref,
      );
  @override
  Future<void> startScan({
    required String facultyId,
    required String classId,
    required String subject,
    String? expectedRoom,
    String? sessionId,
  }) async {
    state = AttendanceScanState(
      phase: initialPhase,
      subject: subject,
      roomId: expectedRoom,
    );
  }

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }
}
