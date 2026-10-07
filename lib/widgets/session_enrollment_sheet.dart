import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../models/schedule_model.dart';
import '../models/user_model.dart';
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
  final _selected = <String>{};
  String _search = '';
  String? _error;
  int _minutes = 30;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load = _loadData();
  }

  Future<List<AppUser>> _loadData() async {
    final service = ref.read(sessionServiceProvider);
    final enrolled = await service
        .streamEnrollment(widget.facultyId, widget.schedule.id)
        .first
        .timeout(const Duration(seconds: 15));
    final students = await service.streamStudents().first.timeout(
      const Duration(seconds: 15),
    );
    if (mounted) {
      setState(() {
        _selected
          ..clear()
          ..addAll(enrolled);
        _loaded = true;
      });
    }
    return students;
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
        );
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.openSession
                  ? 'Attendance opened for selected students.'
                  : 'Class enrollment saved.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save. Check your connection and faculty approval, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * .82 - keyboard).clamp(
      180.0,
      850.0,
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
                  const SizedBox(height: 8),
                  const Text(
                    'Select only students enrolled in this class. Existing sessions keep the enrollment recorded when they opened.',
                  ),
                  const SizedBox(height: 14),
                  if (widget.openSession) ...[
                    DropdownButtonFormField<int>(
                      initialValue: _minutes,
                      decoration: const InputDecoration(
                        labelText: 'Attendance window',
                      ),
                      items: const [10, 15, 30, 60]
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
                  const SizedBox(height: 12),
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
    final students =
        snapshot.data!
            .where(
              (s) => '${s.displayName} ${s.email} ${s.uid}'
                  .toLowerCase()
                  .contains(_search),
            )
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
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
