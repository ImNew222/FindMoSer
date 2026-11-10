import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../attendance/models/schedule_model.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../core/campus_time.dart';
import '../../../shared/widgets/glass_card.dart';
import '../widgets/schedule_dialogs.dart';
import '../../attendance/widgets/session_enrollment_sheet.dart';
import '../widgets/roster_sheet.dart';

class FacultyScheduleTab extends ConsumerStatefulWidget {
  const FacultyScheduleTab({super.key});
  @override
  ConsumerState<FacultyScheduleTab> createState() => _FacultyScheduleTabState();
}

class _FacultyScheduleTabState extends ConsumerState<FacultyScheduleTab> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  late String _day;
  @override
  void initState() {
    super.initState();
    _day = _days[CampusTime.wallClock(DateTime.now()).weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileStreamProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          const Center(child: Text('Your profile could not be loaded.')),
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Class schedule',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Room IDs must match the beacon exactly. All class times use Cebu time.',
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _days
                    .map(
                      (day) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(day.substring(0, 3)),
                          selected: day == _day,
                          onSelected: (_) => setState(() => _day = day),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<ClassSchedule>>(
                stream: ref
                    .watch(firestoreServiceProvider)
                    .streamFacultySchedule(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Schedule could not be loaded. Check your connection and faculty approval.',
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final schedules =
                      snapshot.data!.where((s) => s.dayOfWeek == _day).toList()
                        ..sort((a, b) => a.startTime.compareTo(b.startTime));
                  if (schedules.isEmpty) {
                    return Center(child: Text('No classes for $_day.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: schedules.length,
                    itemBuilder: (context, i) {
                      final schedule = schedules[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      schedule.subject,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete scheduled class',
                                    onPressed: () =>
                                        ScheduleDialogs.confirmDelete(
                                          context: context,
                                          facultyId: user.uid,
                                          schedule: schedule,
                                          selectedDay: _day,
                                        ),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppTheme.error,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${CampusTime.hhmm12(schedule.startTime)}–${CampusTime.hhmm12(schedule.endTime)} • ${schedule.roomName}',
                              ),
                              if (schedule.joinCode.isNotEmpty)
                                Text(
                                  'Class code: ${schedule.joinCode}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => showRosterSheet(
                                      context,
                                      facultyId: user.uid,
                                      classId: schedule.id,
                                      subject: schedule.subject,
                                    ),
                                    icon: const Icon(Icons.list_alt_outlined),
                                    label: const Text('Class Roster'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => showSessionEnrollmentSheet(
                                      context,
                                      facultyId: user.uid,
                                      schedule: schedule,
                                      openSession: false,
                                    ),
                                    icon: const Icon(Icons.groups_outlined),
                                    label: const Text('Enrollment'),
                                  ),
                                  FilledButton(
                                    onPressed: () => showSessionEnrollmentSheet(
                                      context,
                                      facultyId: user.uid,
                                      schedule: schedule,
                                    ),
                                    child: const Text('Open attendance'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ScheduleDialogs.showAddClass(
                    context: context,
                    facultyId: user.uid,
                    selectedDay: _day,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add class'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
