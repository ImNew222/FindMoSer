import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../config/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/attendance_provider.dart';
import '../../../providers/attendance_sessions_provider.dart';
import '../../../providers/campus_clock_provider.dart';
import '../../../widgets/attendance_card.dart';
import '../../../widgets/attendance_session_card.dart';
import '../../../widgets/class_picker_sheet.dart';
import '../../../widgets/glass_card.dart';

class StudentHomeTab extends ConsumerWidget {
  const StudentHomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileStreamProvider).value;
    final sessions = ref.watch(studentSessionsProvider);
    final now = ref.watch(campusClockProvider).value ?? DateTime.now();
    final receipts = ref.watch(studentAttendanceTodayProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, ${user?.displayName ?? 'Student'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        const Text(
          'Your classes and attendance in one place.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 36,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Ready for class?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose an open session, enter the assigned room, and keep this screen open while your beacon signal is checked.',
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => showClassPickerSheet(context),
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Check attendance'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Open classes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        sessions.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(studentSessionsProvider),
            child: const Text('Unable to load classes. Retry'),
          ),
          data: (list) {
            final active = list.where((s) => isSessionOpenAt(s, now)).toList()
              ..sort((a, b) => a.closesAt.compareTo(b.closesAt));
            if (active.isEmpty) {
              return const Text(
                'No open attendance sessions. Your faculty must enroll you and open the class session.',
              );
            }
            return Column(
              children: active
                  .map(
                    (s) => AttendanceSessionCard(
                      session: s,
                      actionLabel: 'Check attendance',
                      onAction: () => openAttendanceSession(context, s),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Today’s receipts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        receipts.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton(
            onPressed: () => ref.invalidate(studentAttendanceTodayProvider),
            child: const Text('Unable to load receipts. Retry'),
          ),
          data: (list) => list.isEmpty
              ? const Text('No attendance receipts yet.')
              : Column(
                  children:
                      (list.toList()..sort(
                            (a, b) =>
                                b.localTimestamp.compareTo(a.localTimestamp),
                          ))
                          .take(3)
                          .map((r) => AttendanceCard(record: r))
                          .toList(),
                ),
        ),
      ],
    );
  }
}
