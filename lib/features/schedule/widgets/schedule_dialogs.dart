import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/campus_time.dart';
import '../../attendance/models/schedule_model.dart';
import '../../../shared/services/firestore_service.dart';

class ScheduleDialogs {
  ScheduleDialogs._();

  static Future<void> showAddClass({
    required BuildContext context,
    required String facultyId,
    required String selectedDay,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AddClassDialog(facultyId: facultyId, day: selectedDay),
  );

  static Future<void> confirmDelete({
    required BuildContext context,
    required String facultyId,
    required ClassSchedule schedule,
    required String selectedDay,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scheduled class?'),
        content: Text(
          'Remove ${schedule.subject} from $selectedDay? Previously opened attendance sessions and receipts will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final done = Completer<void>();
    final blocker = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteBlocker(done: done),
    );
    try {
      await FirestoreService().deleteClassSchedule(
        facultyId: facultyId,
        scheduleId: schedule.id,
      );
      done.complete();
      await blocker;
    } catch (_) {
      done.completeError(StateError('delete failed'));
      await blocker;
    }
  }
}

class _DeleteBlocker extends StatefulWidget {
  final Completer<void> done;
  const _DeleteBlocker({required this.done});
  @override
  State<_DeleteBlocker> createState() => _DeleteBlockerState();
}

class _DeleteBlockerState extends State<_DeleteBlocker> {
  @override
  void initState() {
    super.initState();
    widget.done.future.then(
      (_) {
        if (mounted) Navigator.of(context).pop();
      },
      onError: (Object _) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'The class could not be deleted. Check your connection and retry.',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _AddClassDialog extends StatefulWidget {
  final String facultyId;
  final String day;
  const _AddClassDialog({required this.facultyId, required this.day});
  @override
  State<_AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<_AddClassDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _room = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _subject.dispose();
    _room.dispose();
    super.dispose();
  }

  static String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick({required bool start}) async {
    final initial = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: start ? 'Class starts (AM/PM)' : 'Class ends (AM/PM)',
    );
    if (picked != null) {
      setState(() => start ? _start = picked : _end = picked);
    }
  }

  String _display(TimeOfDay t) => CampusTime.hhmm12(_hhmm(t));
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_hhmm(_start).compareTo(_hhmm(_end)) >= 0) {
      setState(() => _error = 'End time must be later than start time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FirestoreService().addClassSchedule(
        facultyId: widget.facultyId,
        schedule: ClassSchedule(
          id: '',
          dayOfWeek: widget.day,
          startTime: _hhmm(_start),
          endTime: _hhmm(_end),
          roomName: _room.text.trim(),
          subject: _subject.text.trim(),
          joinCode: JoinCode.generate(),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save class. Check your connection and faculty approval.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Add ${widget.day} class'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _subject,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Subject'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter the subject.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _room,
                enabled: !_saving,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Exact beacon room ID',
                  hintText: 'Room305',
                  helperText: 'For FindMoSer_Room305, enter Room305.',
                  helperMaxLines: 2,
                ),
                validator: (v) =>
                    v == null || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v.trim())
                    ? 'Use the exact room ID, without spaces.'
                    : null,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick select beacon room:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  'ComputerLab1',
                  'ComputerLab2',
                  'ComputerLab3',
                  'ComputerLab4',
                  'ComputerLab5',
                  'CL1',
                  'CL2',
                  'CL3',
                  'CL4',
                  'CL5',
                  'DeanOffice',
                  'Library',
                ].map((room) => ActionChip(
                  label: Text(room, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: _saving ? null : () {
                    setState(() {
                      _room.text = room;
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Starts'),
                      subtitle: Text(_display(_start)),
                      enabled: !_saving,
                      onTap: () => _pick(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ends'),
                      subtitle: Text(_display(_end)),
                      enabled: !_saving,
                      onTap: () => _pick(start: false),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save class'),
        ),
      ],
    ),
  );
}
