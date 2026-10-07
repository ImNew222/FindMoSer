import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/schedule_model.dart';
import '../services/firestore_service.dart';

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
    try {
      await FirestoreService().deleteClassSchedule(
        facultyId: facultyId,
        scheduleId: schedule.id,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The class could not be deleted. Check your connection and retry.',
            ),
          ),
        );
      }
    }
  }
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
  final _start = TextEditingController(text: '08:00');
  final _end = TextEditingController(text: '09:00');
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _subject.dispose();
    _room.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String? _validTime(String? value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value ?? '')
      ? null
      : 'Use HH:mm';
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_start.text.compareTo(_end.text) >= 0) {
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
          startTime: _start.text,
          endTime: _end.text,
          roomName: _room.text.trim(),
          subject: _subject.text.trim(),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _start,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Start HH:mm',
                      ),
                      validator: _validTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _end,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'End HH:mm'),
                      validator: _validTime,
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
