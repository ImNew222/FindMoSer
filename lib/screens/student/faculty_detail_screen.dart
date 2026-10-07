import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/schedule_model.dart';
import '../../models/room_model.dart';
import '../../services/location_policy.dart';
import '../../widgets/forecast_card.dart';

final facultyScheduleProvider = StreamProvider.autoDispose
    .family<List<ClassSchedule>, String>(
      (ref, id) =>
          ref.watch(firestoreServiceProvider).streamFacultySchedule(id),
    );
final roomsProvider = FutureProvider<List<Room>>(
  (ref) => ref.watch(firestoreServiceProvider).getRooms(),
);

class FacultyDetailScreen extends ConsumerWidget {
  final String facultyId;
  const FacultyDetailScreen({super.key, required this.facultyId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faculty = ref.watch(allFacultyLocationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Faculty details')),
      body: faculty.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(locationSnapshotProvider),
            child: const Text('Could not load details. Retry'),
          ),
        ),
        data: (list) {
          final f = list
              .where((f) => f.location.facultyId == facultyId)
              .firstOrNull;
          if (f == null) {
            return const Center(
              child: Text('Faculty member is no longer in the directory.'),
            );
          }
          final shared = f.location.isVisible;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // A detail summary avoids a nested link to the same screen.
              Text(
                f.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(f.department), const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: Text(
                  shared ? f.location.publicZone : 'Location not shared',
                ),
                subtitle: Text(
                  shared
                      ? '${f.status == FacultyStatus.online ? 'Recent detection' : 'Last known location'} · ${f.location.timeAgo}'
                      : 'Sharing may be paused or outside configured hours.',
                ),
              ),
              if (shared) ...[
                ForecastCard(facultyId: facultyId),
                const SizedBox(height: 16),
                Text(
                  LocationPolicy.availabilityLabel(
                    f.user?.availability ?? 'unset',
                  ),
                ),
                if (f.user?.workStartTime != null &&
                    f.user?.workEndTime != null)
                  Text(
                    'Sharing hours: ${f.user!.workStartTime}–${f.user!.workEndTime}',
                  ),
                const SizedBox(height: 24),
                Text(
                  'Weekly schedule',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Planned classes do not confirm a live location or consultation availability.',
                ),
                const SizedBox(height: 12),
                ref
                    .watch(facultyScheduleProvider(facultyId))
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => TextButton(
                        onPressed: () =>
                            ref.invalidate(facultyScheduleProvider(facultyId)),
                        child: const Text('Unable to load schedule. Retry'),
                      ),
                      data: (entries) {
                        if (entries.isEmpty) {
                          return const Text('No classes recorded.');
                        }
                        final sorted = [...entries]
                          ..sort(
                            (a, b) => '${a.dayOfWeek}${a.startTime}'.compareTo(
                              '${b.dayOfWeek}${b.startTime}',
                            ),
                          );
                        return Column(
                          children: sorted
                              .map(
                                (s) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(s.subject),
                                  subtitle: Text(
                                    '${s.dayOfWeek} · ${s.startTime}–${s.endTime}\nLocation withheld; see shared zone',
                                  ),
                                  isThreeLine: true,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}
