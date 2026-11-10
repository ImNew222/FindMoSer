import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../presence/providers/ble_provider.dart';
import '../../presence/providers/presence_provider.dart';
import '../../../shared/widgets/app_navigation.dart';
import '../../../shared/widgets/ble_readiness_banner.dart';
import 'faculty_home_tab.dart';
import 'faculty_attendance_tab.dart';
import '../../schedule/screens/faculty_schedule_tab.dart';
import 'faculty_profile_tab.dart';

class FacultyDashboard extends ConsumerStatefulWidget {
  const FacultyDashboard({super.key});
  @override
  ConsumerState<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends ConsumerState<FacultyDashboard> {
  int _tab = 0;
  FacultyLocationUpdater? _updater;
  ProviderSubscription<AsyncValue<User?>>? _authSub;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Listen from initState so a UID that arrives before the first build is
    // not missed. The immediate callback also covers an already-signed-in user.
    _authSub = ref.listenManual(authStateProvider, (_, next) {
      if (next.value?.uid != null) _startUpdater();
    }, fireImmediately: true);
  }

  Future<void> _startUpdater() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _updater != null || _starting) return;
    _starting = true;
    // Publish the directory entry (and create the missing location doc) before
    // the first scan, otherwise the updater's visibility check skips a cycle.
    try {
      await ref.read(presenceServiceProvider).sync(uid);
    } catch (_) {
      // The updater still retries the presence sync after each detection.
    } finally {
      _starting = false;
    }
    if (!mounted || _updater != null) return;
    _updater = FacultyLocationUpdater(
      scanner: ref.read(bleScannerProvider),
      firestoreService: ref.read(firestoreServiceProvider),
      presenceService: ref.read(presenceServiceProvider),
      facultyId: uid,
    )..start();
  }

  @override
  void dispose() {
    _authSub?.close();
    _updater?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Faculty workspace')),
    body: SafeArea(
      child: Column(
        children: [
          const BleReadinessBanner(),
          Expanded(
            child: AppNavigation(
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
              destinations: const [
                (Icons.home_outlined, 'Home'),
                (Icons.fact_check_outlined, 'Attendance'),
                (Icons.calendar_month_outlined, 'Schedule'),
                (Icons.person_outline, 'Profile'),
              ],
              child: IndexedStack(
                index: _tab,
                children: const [
                  FacultyHomeTab(),
                  FacultyAttendanceTab(),
                  FacultyScheduleTab(),
                  FacultyProfileTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
