import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import 'glass_card.dart';

/// Summary card for a single class showing attendance counts.
///
/// Used on the faculty attendance dashboard to show per-class stats.
class AttendanceClassSummary extends StatelessWidget {
  final String subject;
  final String timeRange;   // e.g. "09:00 – 10:30"
  final String roomName;
  final int presentCount;
  final VoidCallback? onTap;

  const AttendanceClassSummary({
    super.key,
    required this.subject,
    required this.timeRange,
    required this.roomName,
    required this.presentCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Present count badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: presentCount > 0
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$presentCount',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: presentCount > 0
                          ? AppTheme.success
                          : AppTheme.textHint,
                    ),
                  ),
                  Text(
                    'present',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Class info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$timeRange • $roomName',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
