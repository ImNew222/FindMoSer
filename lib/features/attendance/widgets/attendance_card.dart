import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../models/attendance_model.dart';
import 'attendance_session_card.dart';
import '../../../shared/widgets/glass_card.dart';

class AttendanceCard extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback? onTap;
  const AttendanceCard({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final rejected = record.syncStatus == SyncStatus.failed;
    final confirmed = !rejected && record.isSynced;
    final label = rejected
        ? 'Rejected'
        : confirmed
        ? 'Confirmed'
        : 'Pending upload';
    final color = rejected
        ? AppTheme.error
        : confirmed
        ? AppTheme.success
        : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    record.subject,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  rejected
                      ? Icons.error_outline
                      : confirmed
                      ? Icons.check_circle_outline
                      : Icons.cloud_upload_outlined,
                  color: color,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Room ID: ${record.roomId} • ${record.date}'),
            Text(
              'Recorded ${cebuTime(record.localTimestamp)} (Cebu)',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                if (confirmed) Text('Attendance: ${record.attendanceStatus}'),
                if (confirmed && record.cached)
                  const Text(
                    'Saved copy',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
              ],
            ),
            if (confirmed && record.serverTimestamp != null)
              Text(
                'Server confirmed ${cebuTime(record.serverTimestamp!)} (Cebu)',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            if (!confirmed) ...[
              const SizedBox(height: 6),
              Text(
                rejected
                    ? record.failureReason ??
                          'The server did not accept this attendance. Contact your faculty.'
                    : 'Waiting for server approval. This is not yet confirmed attendance.',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ],
            if (record.sessionId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Session: ${record.sessionId}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
