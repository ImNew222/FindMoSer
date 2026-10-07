import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/app_theme.dart';
import '../services/attendance_service.dart';

/// Neumorphic export button that generates and shares a CSV file.
///
/// Used on the faculty attendance dashboard/roster to export records.
class AttendanceExportButton extends StatefulWidget {
  final String facultyId;
  final String classId;
  final String subject;
  final String? sessionId;
  final String? fromDate;
  final String? toDate;

  const AttendanceExportButton({
    super.key,
    required this.facultyId,
    required this.classId,
    required this.subject,
    this.sessionId,
    this.fromDate,
    this.toDate,
  });

  @override
  State<AttendanceExportButton> createState() => _AttendanceExportButtonState();
}

class _AttendanceExportButtonState extends State<AttendanceExportButton> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      final service = AttendanceService();
      final records = await service.getAttendanceForExport(
        facultyId: widget.facultyId,
        classId: widget.classId,
        sessionId: widget.sessionId,
        fromDate: widget.fromDate,
        toDate: widget.toDate,
      );

      if (records.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No attendance records to export.')),
          );
        }
        return;
      }

      final csv = service.generateCsv(records);
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/attendance_${widget.subject.replaceAll(RegExp(r"[^A-Za-z0-9_-]"), "_")}_${widget.fromDate ?? 'all'}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles([
        XFile(file.path),
      ], subject: 'Attendance — ${widget.subject}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !_exporting,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _exporting ? null : _export,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppTheme.neumorphicDecoration(borderRadius: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_exporting)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                )
              else
                const Icon(
                  Icons.file_download_outlined,
                  color: AppTheme.primary,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                _exporting ? 'Exporting...' : 'Export CSV',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
