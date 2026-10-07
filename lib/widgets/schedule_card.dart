import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';
import '../models/schedule_model.dart';
import 'glass_card.dart';

/// A single schedule entry card showing time, subject, room, and delete action.
class ScheduleCard extends StatelessWidget {
  final ClassSchedule schedule;
  final VoidCallback onDelete;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Time column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schedule.startTime,
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              Text(
                schedule.endTime,
                style: GoogleFonts.inter(
                  color: AppTheme.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Subject and room
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.subject,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  schedule.roomName,
                  style: GoogleFonts.inter(color: AppTheme.primary),
                ),
              ],
            ),
          ),

          // Delete button
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.error,
              size: 20,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
