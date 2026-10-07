import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../models/attendance_session_model.dart';
import '../../models/user_model.dart';
import '../../providers/attendance_sessions_provider.dart';
import '../../providers/campus_clock_provider.dart';
import '../../widgets/attendance_export_button.dart';
import '../../widgets/attendance_session_card.dart';
import '../../widgets/glass_card.dart';

class AttendanceRosterScreen extends ConsumerStatefulWidget {
  final AttendanceSession session;
  const AttendanceRosterScreen({super.key, required this.session});

  @override
  ConsumerState<AttendanceRosterScreen> createState() =>
      _AttendanceRosterScreenState();
}

class _AttendanceRosterScreenState
    extends ConsumerState<AttendanceRosterScreen> {
  late Stream<List<AppUser>> _students;
  String _search = '';
  bool _closing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _students = ref.read(sessionServiceProvider).streamStudents();
  }

  Future<void> _close(AttendanceSession session) async {
    setState(() {
      _closing = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionServiceProvider)
          .closeSession(sessionId: session.id, facultyId: session.facultyId);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not close attendance. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _correct(AttendanceRecord record) async {
    final correction = await showDialog<({String status, String reason})>(
      context: context,
      builder: (_) => _CorrectionDialog(record: record),
    );
    if (correction == null || !mounted) return;
    try {
      await ref
          .read(sessionServiceProvider)
          .correctAttendance(
            recordId: record.id,
            facultyId: widget.session.facultyId,
            status: correction.status,
            reason: correction.reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correction saved with an audit record.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Correction was not saved. Check your connection and retry.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(facultySessionsProvider).value ?? [];
    final session =
        sessions.where((s) => s.id == widget.session.id).firstOrNull ??
        widget.session;
    final records = ref.watch(sessionRecordsProvider(session.id));
    final now = ref.watch(campusClockProvider).value ?? DateTime.now();
    final isOpen = isSessionOpenAt(session, now);
    return Scaffold(
      appBar: AppBar(title: Text(session.subject)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AttendanceSessionCard(
            session: session,
            trailing: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AttendanceExportButton(
                  facultyId: session.facultyId,
                  classId: session.classId,
                  sessionId: session.id,
                  subject: session.subject,
                  fromDate: session.date,
                  toDate: session.date,
                ),
                if (isOpen)
                  OutlinedButton.icon(
                    onPressed: _closing ? null : () => _close(session),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(_closing ? 'Closing…' : 'Close attendance'),
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Live class roster',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Missing receipts are not confirmed absences. Connect to refresh before making attendance decisions.',
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search name or student ID',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 20),
          records.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance could not be loaded. No absence counts are available until the roster loads.',
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(sessionRecordsProvider(session.id)),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: (receipts) => StreamBuilder<List<AppUser>>(
              stream: _students,
              builder: (context, snapshot) {
                final names = {
                  for (final s in snapshot.data ?? <AppUser>[])
                    s.uid: s.displayName,
                };
                final byStudent = {for (final r in receipts) r.studentId: r};
                final enrolled = session.enrolledStudentIds.toSet();
                final ids = enrolled.toList()
                  ..sort(
                    (a, b) => (names[a] ?? byStudent[a]?.studentName ?? a)
                        .compareTo(names[b] ?? byStudent[b]?.studentName ?? b),
                  );
                final confirmed = receipts
                    .where((r) => enrolled.contains(r.studentId) && r.isSynced)
                    .toList();
                final missing = enrolled
                    .where((id) => byStudent[id]?.isSynced != true)
                    .length;
                final visible = ids
                    .where(
                      (id) =>
                          '$id ${names[id] ?? byStudent[id]?.studentName ?? ''}'
                              .toLowerCase()
                              .contains(_search),
                    )
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('${ids.length} enrolled')),
                        Chip(
                          label: Text(
                            '${confirmed.where((r) => r.attendanceStatus == 'present').length} present',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${confirmed.where((r) => r.attendanceStatus == 'late').length} late',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${confirmed.where((r) => r.attendanceStatus == 'excused').length} excused',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '${confirmed.where((r) => r.attendanceStatus == 'absent').length} marked absent',
                          ),
                        ),
                        Chip(
                          label: Text(
                            '$missing ${isOpen ? 'waiting' : 'without receipt'}',
                          ),
                        ),
                      ],
                    ),
                    if (receipts.any((r) => r.cached))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Saved roster copy: connect to refresh before making attendance decisions.',
                          style: TextStyle(color: AppTheme.warning),
                        ),
                      ),
                    if (snapshot.hasError)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Student names could not be loaded. IDs and submitted names remain available.',
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const Text('No students match your search.'),
                    ...visible.map((id) {
                      final record = byStudent[id];
                      final status = record?.isSynced == true
                          ? record!.attendanceStatus
                          : isOpen
                          ? 'waiting'
                          : 'no receipt';
                      final name = names[id] ?? record?.studentName ?? id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    status,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: status == 'absent'
                                          ? AppTheme.error
                                          : AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                id,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (record != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  record.isSynced
                                      ? 'Server receipt ${cebuTime(record.serverTimestamp ?? record.localTimestamp)} (Cebu)'
                                      : 'Awaiting server confirmation',
                                ),
                                if (record.isSynced)
                                  TextButton.icon(
                                    onPressed: () => _correct(record),
                                    icon: const Icon(Icons.edit_note),
                                    label: const Text('Correct attendance'),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionDialog extends StatefulWidget {
  final AttendanceRecord record;
  const _CorrectionDialog({required this.record});
  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _status;
  @override
  void initState() {
    super.initState();
    _status = widget.record.attendanceStatus;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Correct attendance'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.record.studentName),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Attendance status'),
              items: [
                'present',
                'late',
                'excused',
                'absent',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) => setState(() => _status = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason for correction',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Enter a reason of at least 10 characters.'
                  : null,
            ),
            const Text(
              'Your account, reason, and the original status will be kept in the audit record.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _status == widget.record.attendanceStatus
            ? null
            : () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, (
                    status: _status,
                    reason: _reason.text.trim(),
                  ));
                }
              },
        child: const Text('Save correction'),
      ),
    ],
  );
}
