import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/app_theme.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/attendance_scan_widgets.dart';

/// A session verifies attendance. Without a session this is a beacon diagnostic.
class AttendanceScanScreen extends ConsumerStatefulWidget {
  final String facultyId;
  final String classId;
  final String subject;
  final String facultyName;
  final String? roomName;
  final String? sessionId;

  const AttendanceScanScreen({
    super.key,
    required this.facultyId,
    required this.classId,
    required this.subject,
    required this.facultyName,
    this.roomName,
    this.sessionId,
  });

  @override
  ConsumerState<AttendanceScanScreen> createState() =>
      _AttendanceScanScreenState();
}

class _AttendanceScanScreenState extends ConsumerState<AttendanceScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  late final AnimationController _successController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: .8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    ref.listenManual(attendanceScanProvider, (previous, next) {
      if (previous?.phase == next.phase) return;
      if (next.isSuccess) {
        _pulseController.stop();
        if (MediaQuery.disableAnimationsOf(context)) {
          _successController.value = 1;
        } else {
          _successController.forward(from: 0);
        }
        HapticFeedback.heavyImpact();
      } else if (next.isFailed) {
        _pulseController.stop();
        HapticFeedback.vibrate();
      } else if (next.phase == AttendanceScanPhase.diagnostic ||
          next.isSubmitting) {
        _pulseController.stop();
      } else if (next.isScanning && !MediaQuery.disableAnimationsOf(context)) {
        _pulseController.repeat(reverse: true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retry();
    });
  }

  bool _scanInterrupted = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A permission dialog may make the app inactive. Leaving the foreground
    // invalidates evidence collected for an unfinished scan.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      final scan = ref.read(attendanceScanProvider);
      if (scan.isScanning || scan.isDwelling) _scanInterrupted = true;
      ref.read(attendanceScanProvider.notifier).onBackground();
    } else if (state == AppLifecycleState.resumed && _scanInterrupted) {
      setState(() => _scanInterrupted = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 4),
          content: Text(
            'The scanner stopped while FindMoSer was in the background. Hold this phone in view of the room beacon.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(attendanceScanProvider);
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) ref.read(attendanceScanProvider.notifier).cancel();
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            widget.sessionId == null ? 'Test beacon' : 'Check attendance',
          ),
          leading: IconButton(
            tooltip: scan.isSubmitting
                ? 'Close; submission continues'
                : 'Close scanner',
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 48).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AttendanceClassInfoHeader(
                        subject: scan.subject ?? widget.subject,
                        facultyName: widget.facultyName,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            _visual(scan),
                            const SizedBox(height: 32),
                            AttendanceScanStatusText(
                              scan: scan,
                              subject: scan.subject ?? widget.subject,
                            ),
                          ],
                        ),
                      ),
                      AttendanceScanActions(
                        scan: scan,
                        onRetry: _retry,
                        onDone: _done,
                        onCancel: _close,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _visual(AttendanceScanState scan) => switch (scan.phase) {
    AttendanceScanPhase.success => AttendanceSuccessVisual(
      scale: _successScale,
    ),
    AttendanceScanPhase.failed => const AttendanceFailedVisual(),
    AttendanceScanPhase.dwelling => AttendanceDwellVisual(scan: scan),
    AttendanceScanPhase.pending ||
    AttendanceScanPhase.recording => const AttendancePendingVisual(),
    AttendanceScanPhase.diagnostic => const AttendanceDiagnosticVisual(),
    _ => AttendanceScanningVisual(animation: _pulseAnimation),
  };

  void _retry() => ref
      .read(attendanceScanProvider.notifier)
      .startScan(
        facultyId: widget.facultyId,
        classId: widget.classId,
        subject: widget.subject,
        expectedRoom: widget.roomName,
        sessionId: widget.sessionId,
      );

  void _close() => Navigator.pop(context);
  void _done() =>
      Navigator.pop(context, ref.read(attendanceScanProvider).isSuccess);
}
