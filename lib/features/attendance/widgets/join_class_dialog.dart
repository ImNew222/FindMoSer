import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/campus_time.dart';
import '../models/attendance_session_model.dart';
import '../models/schedule_model.dart';
import '../screens/student/attendance_scan_screen.dart';
import '../providers/attendance_sessions_provider.dart';
import '../../../shared/providers/auth_provider.dart';

/// Students enroll in a class by typing the short code from their teacher.
Future<void> showJoinClassDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const _JoinClassDialog(),
);

class _JoinClassDialog extends ConsumerStatefulWidget {
  const _JoinClassDialog();
  @override
  ConsumerState<_JoinClassDialog> createState() => _JoinClassDialogState();
}

class _JoinClassDialogState extends ConsumerState<_JoinClassDialog> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// The oldest open session today for this class code, or null. Reading is
  /// authorized for code members by the joinCode fallback in the rules.
  Future<AttendanceSession?> _findOpenSession(String code) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('joinCode', isEqualTo: code)
          .where('date', isEqualTo: CampusTime.dateKey(DateTime.now()))
          .where('status', isEqualTo: 'open')
          .get()
          .timeout(const Duration(seconds: 10));
      final sessions = snapshot.docs
          .map(AttendanceSession.fromFirestore)
          .where((s) => s.isOpen)
          .toList()
        ..sort((a, b) => a.openedAt.compareTo(b.openedAt));
      return sessions.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> _join() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) {
      setState(() => _error = 'Sign in before joining a class.');
      return;
    }
    final code = JoinCode.normalize(_code.text);
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character class code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(sessionServiceProvider)
          .enrollWithCode(studentId: uid, code: code);
      // A late joiner has no way to see the frozen-roster session card, so
      // re-entering the code is their door into an open attendance window.
      final openSession = await _findOpenSession(code);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      if (openSession != null) {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => AttendanceScanScreen(
              facultyId: openSession.facultyId,
              classId: openSession.classId,
              sessionId: openSession.id,
              subject: openSession.subject,
              facultyName: 'Faculty attendance session',
              roomName: openSession.roomId,
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Joined ${result.subject} (${result.dayOfWeek} ${CampusTime.hhmm12(result.startTime)}–${CampusTime.hhmm12(result.endTime)}).',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Join a class'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the class code from your teacher. You only need to do this once per subject.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            enabled: !_busy,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Class code',
              hintText: 'ABC123',
            ),
            onSubmitted: (_) => _join(),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTheme.error)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _busy ? null : _join,
        child: Text(_busy ? 'Joining…' : 'Join class'),
      ),
    ],
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
