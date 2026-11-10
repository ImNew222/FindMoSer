import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../models/schedule_model.dart';
import '../../../core/user_model.dart';
import '../providers/attendance_sessions_provider.dart';

Future<void> showSessionEnrollmentSheet(
  BuildContext context, {
  required String facultyId,
  required ClassSchedule schedule,
  bool openSession = true,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppTheme.background,
  builder: (_) => SessionEnrollmentSheet(
    facultyId: facultyId,
    schedule: schedule,
    openSession: openSession,
  ),
);

class SessionEnrollmentSheet extends ConsumerStatefulWidget {
  final String facultyId;
  final ClassSchedule schedule;
  final bool openSession;
  const SessionEnrollmentSheet({
    super.key,
    required this.facultyId,
    required this.schedule,
    this.openSession = true,
  });
  @override
  ConsumerState<SessionEnrollmentSheet> createState() =>
      _SessionEnrollmentSheetState();
}

class _SessionEnrollmentSheetState
    extends ConsumerState<SessionEnrollmentSheet> {
  late Future<List<AppUser>> _load;
  late Future<String?> _code;
  final _selected = <String>{};
  final _bulk = TextEditingController();
  String _search = '';
  String? _error;
  String? _bulkMessage;
  String? _joinCode;
  int _minutes = 30;
  bool _busy = false;
  bool _loaded = false;
  bool _codeFailed = false;

  @override
  void initState() {
    super.initState();
    _code = _loadCode();
    _minutes = _defaultMinutes();
    _load = _loadData();
  }

  @override
  void dispose() {
    _bulk.dispose();
    super.dispose();
  }

  int _minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Defaults the attendance window to the class period length (10–240 min).
  int _defaultMinutes() {
    final pattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
    final start = widget.schedule.startTime;
    final end = widget.schedule.endTime;
    if (!pattern.hasMatch(start) || !pattern.hasMatch(end)) return 30;
    final length = _minutesOf(end) - _minutesOf(start);
    if (length <= 0) return 30;
    return length.clamp(10, 240);
  }

  void _retryCode() {
    setState(() => _codeFailed = false);
    _code = _loadCode();
  }

  Future<String?> _loadCode() async {
    try {
      final code = await ref
          .read(sessionServiceProvider)
          .ensureJoinCode(
            facultyId: widget.facultyId,
            classId: widget.schedule.id,
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _joinCode = code);
      return code;
    } catch (_) {
      // Enrollment still works without a code; students can also be selected.
      if (mounted) setState(() => _codeFailed = true);
      return null;
    }
  }

  Future<List<AppUser>> _loadData() async {
    final service = ref.read(sessionServiceProvider);
    final code = await _code;    final enrolled = await service
        .streamEnrollment(widget.facultyId, widget.schedule.id)
        .first
        .timeout(const Duration(seconds: 15));
    final members = await service
        .joinCodeMembers(code ?? '')
        .timeout(const Duration(seconds: 15));
    final students = await service.streamStudents().first.timeout(
      const Duration(seconds: 15),
    );
    if (mounted) {
      setState(() {
        _selected
          ..clear()
          ..addAll({...enrolled, ...members});
        _loaded = true;
      });
    }
    return students;
  }

  List<AppUser> _visibleStudents(List<AppUser> all) =>
      all
          .where(
            (s) => '${s.displayName} ${s.email} ${s.uid}'
                .toLowerCase()
                .contains(_search),
          )
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

  void _applyBulk(List<AppUser> students) {
    final tokens = _bulk.text
        .split(RegExp(r'[\s,;]+'))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    if (tokens.isEmpty) {
      setState(() => _bulkMessage = 'Paste student emails or IDs first.');
      return;
    }
    final matched = students.where((s) {
      final email = s.email.toLowerCase();
      final uid = s.uid.toLowerCase();
      return tokens.contains(email) ||
          tokens.contains(uid) ||
          tokens.contains(s.displayName.toLowerCase());
    }).toList();
    final missing = tokens.where((token) {
      return !students.any(
        (s) =>
            s.email.toLowerCase() == token ||
            s.uid.toLowerCase() == token ||
            s.displayName.toLowerCase() == token,
      );
    }).toList();
    final capacityLeft = 200 - _selected.length;
    final overflow = matched.length > capacityLeft;
    setState(() {
      if (capacityLeft > 0) {
        _selected.addAll(matched.take(capacityLeft).map((s) => s.uid));
      }
      _bulkMessage = tokens.isEmpty
          ? null
          : overflow
          ? 'Class capacity reached: a session supports at most 200 students.'
          : missing.isEmpty
          ? 'Added ${matched.length} student(s).'
          : 'Added ${matched.length}. Not found: ${missing.take(5).join(', ')}'
                '${missing.length > 5 ? '…' : ''}';
    });
  }

  Future<void> _copyCode() async {
    final code = _joinCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class code copied.')));
    }
  }

  Future<void> _save() async {
    if (_busy || !_loaded || (widget.openSession && _selected.isEmpty)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(sessionServiceProvider);
      final students = _selected.toList()..sort();
      await service.setEnrollment(
        facultyId: widget.facultyId,
        classId: widget.schedule.id,
        studentIds: students,
      );
      if (widget.openSession) {
        await service.openSession(
          facultyId: widget.facultyId,
          schedule: widget.schedule,
          studentIds: students,
          duration: Duration(minutes: _minutes),
          joinCode: _joinCode,
        );
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.openSession
                  ? 'Attendance opened for ${students.length} student(s).'
                  : 'Class enrollment saved.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save: ${error.toString().replaceFirst('Bad state: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * .9 - keyboard).clamp(
      180.0,
      900.0,
    );
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: SizedBox(
            height: height,
            child: FutureBuilder<List<AppUser>>(
              future: _load,
              builder: (context, snapshot) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  Text(
                    widget.openSession ? 'Open attendance' : 'Class enrollment',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.schedule.subject} • ${widget.schedule.roomName}',
                  ),
                  const SizedBox(height: 14),
                  _codeCard(),
                  const SizedBox(height: 14),
                  if (widget.openSession) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _minutes,
                      decoration: const InputDecoration(
                        labelText: 'Attendance window',
                      ),
                      items: (<int>{10, 15, 30, 60, _minutes}.toList()
                            ..sort())
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text('$m minutes'),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _minutes = value!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Find student',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 10),
                  _bulkAdd(snapshot),
                  const SizedBox(height: 8),
                  ..._studentOptions(snapshot),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text('${_selected.length}/200 students selected'),
                  if (_selected.length >= 200)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Class capacity reached: a session supports at most 200 students.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed:
                        _busy ||
                            !_loaded ||
                            (widget.openSession && _selected.isEmpty)
                        ? null
                        : _save,
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : widget.openSession
                          ? 'Open attendance now'
                          : 'Save enrollment',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppTheme.neumorphicInsetDecoration(borderRadius: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.vpn_key_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _joinCode == null
                    ? (_codeFailed ? 'Class code unavailable' : 'Preparing class code…')
                    : 'Class code: $_joinCode',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_joinCode != null)
              IconButton(
                tooltip: 'Copy class code',
                onPressed: _copyCode,
                icon: const Icon(Icons.copy_outlined),
              ),
          ],
        ),
        if (_joinCode != null) ...[
          const SizedBox(height: 4),
          const Text(
            'Students can enter this code from Home. You can still select students below.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ] else if (_codeFailed) ...[
          const SizedBox(height: 4),
          const Text(
            'Students can still be selected below; retry when your connection is back.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          TextButton.icon(
            onPressed: _retryCode,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry class code'),
          ),
        ],
      ],
    ),
  );

  Widget _bulkAdd(AsyncSnapshot<List<AppUser>> snapshot) {
    final students = snapshot.data ?? <AppUser>[];
    if (!snapshot.hasData || students.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _bulk,
          enabled: !_busy,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Paste emails or student IDs',
            hintText: 'One per line, or comma separated',
            prefixIcon: Icon(Icons.content_paste),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _applyBulk(students),
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Add pasted students'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(
                      () => _selected.addAll(
                        _visibleStudents(students).map((s) => s.uid),
                      ),
                    ),
              child: const Text('Select all shown'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _selected.removeAll(
                        _visibleStudents(students).map((s) => s.uid),
                      );
                    }),
              child: const Text('Clear shown'),
            ),
          ],
        ),
        if (_bulkMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _bulkMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _studentOptions(AsyncSnapshot<List<AppUser>> snapshot) {
    if (snapshot.hasError) {
      return [
        const Text(
          'Could not load enrollment or students. Approved faculty access and a connection are required.',
        ),
        TextButton(
          onPressed: () => setState(() {
            _loaded = false;
            _load = _loadData();
          }),
          child: const Text('Retry'),
        ),
      ];
    }
    if (!snapshot.hasData) {
      return [const Center(child: CircularProgressIndicator())];
    }
    final students = _visibleStudents(snapshot.data!);
    if (students.isEmpty) {
      return [
        const Text(
          'No matching students. Students must register before enrollment.',
        ),
      ];
    }
    return students
        .map(
          (student) => CheckboxListTile(
            value: _selected.contains(student.uid),
            title: Text(student.displayName),
            subtitle: Text(student.email),
            onChanged:
                _busy ||
                    (_selected.length >= 200 &&
                        !_selected.contains(student.uid))
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _selected.add(student.uid);
                    } else {
                      _selected.remove(student.uid);
                    }
                  }),
          ),
        )
        .toList();
  }
}
