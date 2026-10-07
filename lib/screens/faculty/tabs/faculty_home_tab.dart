import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../models/schedule_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/campus_time.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/session_enrollment_sheet.dart';

/// Faculty opens an attendance window for a scheduled, enrolled class.
class FacultyHomeTab extends ConsumerWidget {
  const FacultyHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileStreamProvider);
    return user.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Unable to load your profile.')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('Sign in to continue.'));
        }
        final today = CampusTime.wallClock(DateTime.now());
        const days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        final day = days[today.weekday - 1];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hello, ${profile.displayName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            const Text(
              'Open attendance when your class is ready.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.school_outlined,
                    color: AppTheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Prepare your class',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add the subject and exact beacon room ID in Schedule. Select enrolled students, then open an attendance window. Follow check-ins in the Attendance tab.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('$day classes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            StreamBuilder<List<ClassSchedule>>(
              stream: ref
                  .watch(firestoreServiceProvider)
                  .streamFacultySchedule(profile.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'Unable to load your schedule. Check your connection and faculty approval.',
                  );
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final classes =
                    snapshot.data!.where((s) => s.dayOfWeek == day).toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime));
                if (classes.isEmpty) {
                  return const Text(
                    'No classes scheduled today. Add your class in the Schedule tab.',
                  );
                }
                return Column(
                  children: classes
                      .map(
                        (schedule) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schedule.subject,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${schedule.startTime}–${schedule.endTime} • ${schedule.roomName}',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () =>
                                          showSessionEnrollmentSheet(
                                            context,
                                            facultyId: profile.uid,
                                            schedule: schedule,
                                          ),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Open attendance'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          showSessionEnrollmentSheet(
                                            context,
                                            facultyId: profile.uid,
                                            schedule: schedule,
                                            openSession: false,
                                          ),
                                      child: const Text('Enrollment'),
                                    ),
                                  ],
                                ),
                              ],
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
      },
    );
  }
}
