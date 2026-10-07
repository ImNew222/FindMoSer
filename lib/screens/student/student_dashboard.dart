import 'package:flutter/material.dart';
import '../../widgets/app_navigation.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_attendance_tab.dart';
import 'tabs/student_profile_tab.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});
  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FindMoSer')),
    body: SafeArea(
      child: AppNavigation(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        destinations: const [
          (Icons.home_outlined, 'Home'),
          (Icons.fact_check_outlined, 'Attendance'),
          (Icons.person_outline, 'Profile'),
        ],
        child: IndexedStack(
          index: _index,
          children: const [
            StudentHomeTab(),
            StudentAttendanceTab(),
            StudentProfileTab(),
          ],
        ),
      ),
    ),
  );
}
