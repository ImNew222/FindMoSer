import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../models/attendance_session_model.dart';
import '../providers/attendance_sessions_provider.dart';
import '../providers/campus_clock_provider.dart';
import '../screens/student/attendance_scan_screen.dart';
import 'attendance_session_card.dart';

void openAttendanceSession(BuildContext context, AttendanceSession session) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceScanScreen(
        facultyId: session.facultyId,
        classId: session.classId,
        sessionId: session.id,
        subject: session.subject,
        facultyName: 'Faculty attendance session',
        roomName: session.roomId,
      ),
    ),
  );
}

void showClassPickerSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.background,
    showDragHandle: true,
    builder: (_) => _ClassPickerContent(
      onSelect: (session) {
        Navigator.pop(context);
        openAttendanceSession(context, session);
      },
      onDiagnostic: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AttendanceScanScreen(
              facultyId: '',
              classId: '',
              subject: 'Test beacon',
              facultyName: 'Diagnostic only • attendance is not submitted',
            ),
          ),
        );
      },
    ),
  );
}

class _ClassPickerContent extends ConsumerWidget {
  final ValueChanged<AttendanceSession> onSelect;
  final VoidCallback onDiagnostic;
  const _ClassPickerContent({
    required this.onSelect,
    required this.onDiagnostic,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(studentSessionsProvider);
    final now = ref.watch(campusClockProvider).value ?? DateTime.now();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Choose attendance session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Only sessions opened by your faculty for your enrolled classes appear here.',
            ),
            const SizedBox(height: 20),
            sessions.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Could not load sessions. Check your connection and account access.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(studentSessionsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (list) {
                final active = list
                    .where((s) => isSessionOpenAt(s, now))
                    .toList();
                if (active.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No open sessions. Ask your faculty to confirm your enrollment and open attendance.',
                    ),
                  );
                }
                return Column(
                  children: active
                      .map(
                        (s) => AttendanceSessionCard(
                          session: s,
                          actionLabel: 'Check attendance',
                          onAction: () => onSelect(s),
                          onCardTap: () => onSelect(s),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const Divider(height: 32),
            OutlinedButton.icon(
              onPressed: onDiagnostic,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Test beacon • no attendance'),
            ),
          ],
        ),
      ),
    );
  }
}
