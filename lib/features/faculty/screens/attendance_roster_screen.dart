import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/user_model.dart';
import '../../attendance/models/attendance_mark_model.dart';
import '../../attendance/models/attendance_model.dart';
import '../../attendance/models/attendance_session_model.dart';
import '../../attendance/services/attendance_service.dart';
import '../../attendance/providers/attendance_sessions_provider.dart';
import '../../attendance/providers/campus_clock_provider.dart';
import '../../attendance/widgets/attendance_export_button.dart';
import '../../attendance/widgets/attendance_session_card.dart';
import '../../../shared/widgets/glass_card.dart';

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
  String? _markingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _students = ref.read(sessionServiceProvider).streamStudents();
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

  Future<void> _mark(AttendanceSession session, String studentId,
      String studentName) async {
    final mark = await showDialog<({String status, String reason})>(
      context: context,
      builder: (_) => const _MarkDialog(),
    );
    if (mark == null || !mounted) return;
    setState(() => _markingId = studentId);
    try {
      await ref.read(sessionServiceProvider).markStudent(
            session: session,
            facultyId: session.facultyId,
            studentId: studentId,
            status: mark.status,
            reason: mark.reason,
            studentName: studentName,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faculty mark recorded.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mark was not saved. Check your connection and retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingId = null);
    }
  }

  /// Assembles the session CSV through the shared builder, merging live
  /// streamed receipts with the server copy so no enrolled student is silently
  /// left out of the file.
  Future<String> _csv(
    List<AttendanceRecord> records,
    List<AttendanceMark> marks,
  ) async {
    final AttendanceSession session = widget.session;
    final service = AttendanceService();
    final serverRecords = await service.getAttendanceForExport(
      facultyId: session.facultyId,
      classId: session.classId,
      sessionId: session.id,
      fromDate: session.date,
      toDate: session.date,
    );
    final merged = <String, AttendanceRecord>{
      for (final r in records.where((r) => r.isSynced)) r.id: r,
      for (final r in serverRecords) r.id: r,
    };
    return service.buildAttendanceCsv(
      records: merged.values.toList(),
      sessions: [session],
      marks: marks,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(facultySessionsProvider).value ?? [];
    final session =
        sessions.where((s) => s.id == widget.session.id).firstOrNull ??
        widget.session;
    final records = ref.watch(sessionRecordsProvider(session.id));
    final marks = ref.watch(sessionMarksProvider(
      (facultyId: session.facultyId, sessionId: session.id),
    ));
    final now = ref.watch(campusClockProvider).value ?? DateTime.now();
    final isOpen = isSessionOpenAt(session, now);
    return Scaffold(
      appBar: AppBar(title: Text(session.subject)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AttendanceSessionCard(
            session: session,
            trailing: AttendanceExportButton(
              facultyId: session.facultyId,
              classId: session.classId,
              sessionId: session.id,
              subject: session.subject,
              fromDate: session.date,
              toDate: session.date,
              label: 'Export attendance',
              csvBuilder: () => _csv(
                records.valueOrNull ?? [],
                marks.valueOrNull ?? [],
              ),
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
                final marksByStudent = {
                  for (final m in (marks.valueOrNull ?? [])) m.studentId: m,
                };
                final enrolled = session.enrolledStudentIds.toSet();
                final ids = enrolled.toList()
                  ..sort(
                    (a, b) => (names[a] ?? byStudent[a]?.studentName ?? a)
                        .compareTo(names[b] ?? byStudent[b]?.studentName ?? b),
                  );
                final confirmed = receipts
                    .where((r) => enrolled.contains(r.studentId) && r.isSynced)
                    .toList();
                final unknown = enrolled
                    .where((id) =>
                        byStudent[id]?.isSynced != true &&
                        !marksByStudent.containsKey(id))
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
                            '$unknown ${isOpen ? 'waiting' : 'without receipt'}',
                          ),
                        ),
                        if (marksByStudent.isNotEmpty)
                          Chip(
                            label: Text('${marksByStudent.length} faculty marks'),
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
                      final mark = marksByStudent[id];
                      final status = record?.isSynced == true
                          ? record!.attendanceStatus
                          : mark != null
                          ? 'marked ${mark.status}'
                          : isOpen
                          ? 'waiting'
                          : 'Absent (no receipt)';
                      final name = names[id] ?? record?.studentName ?? mark?.studentName ?? id;
                      final markedWithoutReceipt = record?.isSynced != true && mark != null;
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
                                      color: status != 'waiting' &&
                                              (status.startsWith('absent') ||
                                                  status == 'marked absent')
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
                              if (markedWithoutReceipt) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Faculty mark: ${mark.status} — ${mark.reason}',
                                ),
                              ],
                              if (record?.isSynced != true &&
                                  mark == null &&
                                  !isOpen) ...[
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  onPressed: _markingId == id
                                      ? null
                                      : () => _mark(session, id, name),
                                  icon: const Icon(Icons.how_to_reg_outlined),
                                  label: Text(
                                    _markingId == id
                                        ? 'Saving…'
                                        : 'Record attendance',
                                  ),
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

class _MarkDialog extends StatefulWidget {
  const _MarkDialog();
  @override
  State<_MarkDialog> createState() => _MarkDialogState();
}

class _MarkDialogState extends State<_MarkDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _status = 'absent';
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record attendance'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The student has no attendance receipt for this closed session.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Attendance status'),
              items: [
                'absent',
                'late',
                'excused',
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
                labelText: 'Reason for this mark',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Enter a reason of at least 10 characters.'
                  : null,
            ),
            const Text(
              'Marks never edit scan evidence. Your account, the status, and this reason are kept for the record.',
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
        onPressed: _form.currentState?.validate() == true
            ? () => Navigator.pop(
                  context,
                  (status: _status, reason: _reason.text.trim()),
                )
            : null,
        child: const Text('Save mark'),
      ),
    ],
  );
}
