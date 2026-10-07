import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/attendance_sessions_provider.dart';
import '../../../widgets/attendance_session_card.dart';
import '../attendance_roster_screen.dart';

class FacultyAttendanceTab extends ConsumerWidget {
  const FacultyAttendanceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(facultySessionsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Today’s attendance sessions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Open a session from Home or Schedule. Each session keeps its own enrollment and attendance receipts.',
        ),
        const SizedBox(height: 24),
        sessions.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sessions could not be loaded. Check your connection and faculty approval.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(facultySessionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Text('No attendance sessions opened today.');
            }
            final sorted = [...items]
              ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
            return Column(
              children: sorted
                  .map(
                    (session) => AttendanceSessionCard(
                      session: session,
                      trailing: Text(
                        '${session.enrolledStudentIds.length} enrolled students',
                      ),
                      actionLabel: 'View live roster',
                      onAction: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AttendanceRosterScreen(session: session),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
