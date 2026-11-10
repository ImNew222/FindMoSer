import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/models/attendance_session_model.dart';
import '../../attendance/models/schedule_model.dart';
import '../../attendance/providers/attendance_sessions_provider.dart';
import '../../attendance/providers/campus_clock_provider.dart';
import '../../attendance/widgets/attendance_export_button.dart';
import '../../attendance/widgets/attendance_session_card.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../core/campus_time.dart';
import '../../../core/app_theme.dart';
import 'attendance_roster_screen.dart';

class FacultyAttendanceTab extends ConsumerStatefulWidget {
  const FacultyAttendanceTab({super.key});

  @override
  ConsumerState<FacultyAttendanceTab> createState() =>
      _FacultyAttendanceTabState();
}

class _FacultyAttendanceTabState extends ConsumerState<FacultyAttendanceTab> {
  String? _closingId;
  String? _exportClassId;
  DateTime _exportFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _exportTo = DateTime.now();

  void _openRoster(AttendanceSession session) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendanceRosterScreen(session: session)),
    );
  }

  Future<void> _close(AttendanceSession session) async {
    setState(() => _closingId = session.id);
    try {
      await ref
          .read(sessionServiceProvider)
          .closeSession(sessionId: session.id, facultyId: session.facultyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance closed. Students without receipts can now be marked from the roster.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not close attendance. Check your connection and try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _closingId = null);
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _exportFrom : _exportTo,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _exportFrom = picked;
        if (_exportFrom.isAfter(_exportTo)) _exportTo = _exportFrom;
      } else {
        _exportTo = picked.isAfter(_exportTo) || picked.isAtSameMomentAs(_exportTo)
            ? picked
            : _exportTo;
        if (_exportTo.isBefore(_exportFrom)) _exportFrom = _exportTo;
      }
    });
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;
    final sessions = ref.watch(facultySessionsProvider);
    final now = ref.watch(campusClockProvider).value ?? DateTime.now();
    final today = CampusTime.dateKey(now);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Today’s attendance sessions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap a card to open its roster. Sessions keep their own enrollment and attendance receipts.',
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
            final todays = items.where((s) => s.date == today).toList();
            final previous = items
                .where((s) => s.date.compareTo(today) < 0)
                .take(10)
                .toList();
            if (todays.isEmpty && previous.isEmpty) {
              return const Text('No attendance sessions have been opened yet.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todays.isEmpty)
                  const Text('No attendance sessions opened today.')
                else
                  ...todays.map((session) => AttendanceSessionCard(
                        session: session,
                        onCardTap: () => _openRoster(session),
                        trailing: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (isSessionOpenAt(session, now))
                              OutlinedButton.icon(
                                onPressed: _closingId == session.id
                                    ? null
                                    : () => _close(session),
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: Text(
                                  _closingId == session.id
                                      ? 'Closing…'
                                      : 'Close attendance',
                                ),
                              ),
                            TextButton.icon(
                              onPressed: () => _openRoster(session),
                              icon: const Icon(Icons.list_alt),
                              label: const Text('Roster'),
                            ),
                          ],
                        ),
                      )),
                if (previous.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Previous sessions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Earlier rosters stay available for marks and corrections.',
                  ),
                  const SizedBox(height: 12),
                  ...previous.map((session) => AttendanceSessionCard(
                        session: session,
                        onCardTap: () => _openRoster(session),
                        trailing: TextButton.icon(
                          onPressed: () => _openRoster(session),
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Roster'),
                        ),
                      )),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        Text(
          'Export class attendance history',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _ExportRangeCard(
          uid: uid,
          exportClassId: _exportClassId,
          fromKey: _dayKey(_exportFrom),
          toKey: _dayKey(_exportTo),
          onClassChanged: (id) => setState(() => _exportClassId = id),
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
        ),
      ],
    );
  }
}

class _ExportRangeCard extends ConsumerWidget {
  final String? uid;
  final String? exportClassId;
  final String fromKey;
  final String toKey;
  final ValueChanged<String?> onClassChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  const _ExportRangeCard({
    required this.uid,
    required this.exportClassId,
    required this.fromKey,
    required this.toKey,
    required this.onClassChanged,
    required this.onPickFrom,
    required this.onPickTo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidValue = uid;
    if (uidValue == null) return const SizedBox.shrink();
    final schedules = ref
        .watch(firestoreServiceProvider)
        .streamFacultySchedule(uidValue);
    return StreamBuilder<List<ClassSchedule>>(
      stream: schedules,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Class history could not be loaded. Check your connection.',
            style: TextStyle(color: AppTheme.warning),
          );
        }
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final schedules = [...snapshot.data!]
          ..sort((a, b) => a.subject.compareTo(b.subject));
        if (schedules.isEmpty) {
          return const Text('Add classes first to export their history.');
        }
        final requestedId = exportClassId;
        final classId = requestedId != null &&
                schedules.any((s) => s.id == requestedId)
            ? requestedId
            : schedules.first.id;
        final schedule = schedules.firstWhere((s) => s.id == classId);
        return GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: classId,
                decoration:
                    const InputDecoration(labelText: 'Class'),
                items: schedules
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.subject} • ${s.roomName}'),
                        ))
                    .toList(),
                onChanged: onClassChanged,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPickFrom,
                      child: Text('From $fromKey'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPickTo,
                      child: Text('To $toKey'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AttendanceExportButton(
                facultyId: uidValue,
                classId: classId,
                subject: schedule.subject,
                fromDate: fromKey,
                toDate: toKey,
                label: 'Export $fromKey → $toKey',
              ),
            ],
          ),
        );
      },
    );
  }
}
