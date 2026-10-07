import 'package:flutter/material.dart';
import '../../widgets/app_navigation.dart';
import 'tabs/faculty_home_tab.dart';
import 'tabs/faculty_attendance_tab.dart';
import 'tabs/faculty_schedule_tab.dart';
import 'tabs/faculty_profile_tab.dart';

class FacultyDashboard extends StatefulWidget {
  const FacultyDashboard({super.key});
  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Faculty workspace')),
    body: SafeArea(
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
  );
}
