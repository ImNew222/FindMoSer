import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/attendance_provider.dart';
import '../../../widgets/attendance_card.dart';
import '../../../widgets/class_picker_sheet.dart';

class StudentAttendanceTab extends ConsumerWidget {
  const StudentAttendanceTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(studentAttendanceTodayProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Today’s attendance',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Only a confirmed receipt means the server accepted your attendance. Pending uploads may be rejected if the session closes before they reach the server.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => showClassPickerSheet(context),
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Check attendance'),
        ),
        const SizedBox(height: 24),
        attendance.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance could not be loaded. Check your connection and account permissions.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(studentAttendanceTodayProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
          data: (records) {
            if (records.isEmpty) {
              return const Text('No attendance records for today.');
            }
            final sorted = [...records]
              ..sort((a, b) => b.localTimestamp.compareTo(a.localTimestamp));
            return Column(
              children: sorted.map((r) => AttendanceCard(record: r)).toList(),
            );
          },
        ),
      ],
    );
  }
}
