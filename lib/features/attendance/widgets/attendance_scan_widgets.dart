import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_theme.dart';
import '../providers/attendance_provider.dart';
import 'dwell_progress_ring.dart';

/// Header card showing which class we're scanning for
class AttendanceClassInfoHeader extends StatelessWidget {
  final String subject;
  final String facultyName;
  const AttendanceClassInfoHeader({
    super.key,
    required this.subject,
    required this.facultyName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.neumorphicDecoration(borderRadius: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: AppTheme.neumorphicInsetDecoration(borderRadius: 12),
            child: const Icon(Icons.class_outlined, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  facultyName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing BLE scan rings
class AttendanceScanningVisual extends StatelessWidget {
  final Animation<double> animation;
  const AttendanceScanningVisual({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Transform.scale(
                  scale: animation.value + (i * 0.15),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(
                          alpha: 0.15 - (i * 0.04),
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.background,
                  boxShadow: AppTheme.mediumShadow,
                ),
                child: const Icon(
                  Icons.bluetooth_searching,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dwell countdown using [DwellProgressRing]
class AttendanceDwellVisual extends StatelessWidget {
  final AttendanceScanState scan;
  const AttendanceDwellVisual({super.key, required this.scan});

  @override
  Widget build(BuildContext context) {
    final remaining = scan.dwellRequired - scan.dwellProgress;
    return DwellProgressRing(
      progress: scan.dwellFraction,
      size: 220,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.background,
          boxShadow: AppTheme.mediumShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$remaining',
              style: GoogleFonts.inter(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            Text(
              'seconds',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green check bounce
class AttendanceSuccessVisual extends StatelessWidget {
  final Animation<double> scale;
  const AttendanceSuccessVisual({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scale,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.success.withValues(alpha: 0.1),
          boxShadow: AppTheme.mediumShadow,
        ),
        child: const Icon(
          Icons.check_circle,
          size: 80,
          color: AppTheme.success,
        ),
      ),
    );
  }
}

/// Red error icon
class AttendanceFailedVisual extends StatelessWidget {
  const AttendanceFailedVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.error.withValues(alpha: 0.08),
        boxShadow: AppTheme.mediumShadow,
      ),
      child: const Icon(Icons.error_outline, size: 72, color: AppTheme.error),
    );
  }
}

/// Title + subtitle + optional signal badge
class AttendanceScanStatusText extends StatelessWidget {
  final AttendanceScanState scan;
  final String subject;
  const AttendanceScanStatusText({
    super.key,
    required this.scan,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (scan.phase) {
      AttendanceScanPhase.idle || AttendanceScanPhase.scanning => (
        'Scanning for beacon...',
        scan.errorMessage ??
            (scan.diagnosticOnly
                ? 'This test does not submit attendance.'
                : 'Stay inside the selected classroom and keep this screen open.'),
      ),
      AttendanceScanPhase.dwelling => (
        'Beacon detected!',
        'Checking continuous signal from ${scan.roomId ?? 'the beacon'}. Stay in the room.',
      ),
      AttendanceScanPhase.recording => (
        'Submitting attendance…',
        'Waiting for the server to confirm your record.',
      ),
      AttendanceScanPhase.success => (
        'Attendance confirmed',
        'The server accepted your attendance for $subject.',
      ),
      AttendanceScanPhase.pending => (
        'Pending confirmation',
        scan.errorMessage ??
            'The server has not confirmed this submission. You may close this screen and check its final status in Attendance.',
      ),
      AttendanceScanPhase.diagnostic => (
        'Beacon test complete',
        'Continuous signal detected from ${scan.roomId ?? 'the beacon'}. No attendance was submitted.',
      ),
      AttendanceScanPhase.failed => (
        'Scan failed',
        scan.errorMessage ?? 'Please try again',
      ),
    };

    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if ((scan.isDwelling ||
                scan.isSuccess ||
                scan.phase == AttendanceScanPhase.diagnostic) &&
            scan.rssi != null) ...[
          const SizedBox(height: 12),
          AttendanceSignalBadge(rssi: scan.rssi!),
        ],
      ],
    );
  }
}

/// Small signal strength indicator chip
class AttendanceSignalBadge extends StatelessWidget {
  final int rssi;
  const AttendanceSignalBadge({super.key, required this.rssi});

  Color get _color {
    if (rssi > -50) return AppTheme.success;
    if (rssi > -65) return AppTheme.primary;
    if (rssi > -80) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: AppTheme.neumorphicInsetDecoration(borderRadius: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.signal_cellular_alt, size: 16, color: _color),
          const SizedBox(width: 8),
          Text(
            '$rssi dBm',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom action buttons: Done / Try Again / Cancel
class AttendanceScanActions extends StatelessWidget {
  final AttendanceScanState scan;
  final VoidCallback onRetry;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  const AttendanceScanActions({
    super.key,
    required this.scan,
    required this.onRetry,
    required this.onDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (scan.isSuccess || scan.phase == AttendanceScanPhase.diagnostic) {
      return _neumorphicButton(
        label: 'Done',
        color: AppTheme.success,
        onTap: onDone,
      );
    }

    if (scan.isFailed) {
      return Column(
        children: [
          _neumorphicButton(
            label: 'Try Again',
            color: AppTheme.primary,
            icon: Icons.refresh,
            onTap: onRetry,
          ),
          const SizedBox(height: 12),
          _cancelText(onCancel),
        ],
      );
    }

    return TextButton(
      onPressed: onCancel,
      child: Text(
        scan.isSubmitting
            ? 'Close • check status in Attendance'
            : 'Cancel scan',
      ),
    );
  }

  Widget _neumorphicButton({
    required String label,
    required Color color,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: AppTheme.neumorphicDecoration(borderRadius: 16),
        child: TextButton(
          onPressed: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cancelText(VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      child: Text(
        'Close scanner',
        style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
      ),
    );
  }
}

/// Waiting is visually distinct from a server-confirmed receipt.
class AttendancePendingVisual extends StatelessWidget {
  const AttendancePendingVisual({super.key});
  @override
  Widget build(BuildContext context) => const _StatusVisual(
    icon: Icons.cloud_upload_outlined,
    color: AppTheme.warning,
    label: 'Awaiting server confirmation',
  );
}

class AttendanceDiagnosticVisual extends StatelessWidget {
  const AttendanceDiagnosticVisual({super.key});
  @override
  Widget build(BuildContext context) => const _StatusVisual(
    icon: Icons.bluetooth_connected,
    color: AppTheme.primary,
    label: 'Beacon diagnostic complete; no attendance submitted',
  );
}

class _StatusVisual extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatusVisual({
    required this.icon,
    required this.color,
    required this.label,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceVariant,
        boxShadow: AppTheme.mediumShadow,
      ),
      child: Icon(icon, size: 72, color: color),
    ),
  );
}
