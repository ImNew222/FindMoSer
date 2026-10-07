import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/campus_clock_provider.dart';
import '../config/app_theme.dart';
import '../models/attendance_session_model.dart';
import 'glass_card.dart';

String cebuTime(DateTime time) {
  final local = time.toUtc().add(const Duration(hours: 8));
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class AttendanceSessionCard extends ConsumerWidget {
  final AttendanceSession session;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  const AttendanceSessionCard({
    super.key,
    required this.session,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(campusClockProvider).value ?? DateTime.now();
    final open = isSessionOpenAt(session, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  open ? Icons.radio_button_checked : Icons.lock_outline,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  open ? 'Open' : 'Closed',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Room ID: ${session.roomId} • ${session.date}'),
            const SizedBox(height: 4),
            Text(
              'Attendance ${cebuTime(session.openedAt)}–${cebuTime(session.closesAt)} (Cebu)',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (trailing != null) ...[const SizedBox(height: 12), trailing!],
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
