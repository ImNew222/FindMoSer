import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import '../services/campus_time.dart';

final forecastProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, id) => FirebaseFirestore.instance
          .collection('availability_forecasts')
          .doc(id)
          .snapshots()
          .map((s) => s.data()),
    );

class ForecastCard extends ConsumerWidget {
  final String facultyId;
  const ForecastCard({super.key, required this.facultyId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ref
            .watch(forecastProvider(facultyId))
            .when(
              loading: () => const Text('Checking availability estimate…'),
              error: (_, __) => const Text(
                'Estimate unavailable. Ask the faculty member to confirm.',
              ),
              data: (data) {
                final expires = (data?['expiresAt'] as Timestamp?)?.toDate();
                if (data == null ||
                    expires == null ||
                    !expires.isAfter(DateTime.now())) {
                  return const Text(
                    'No current prediction. More confirmed observations or a fresh detection may be needed.',
                  );
                }
                String time(Timestamp value) {
                  final t = CampusTime.wallClock(value.toDate());
                  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                }

                final windows = (data['windows'] as List? ?? [])
                    .whereType<Map>()
                    .where(
                      (w) =>
                          w['startsAt'] is Timestamp &&
                          (w['startsAt'] as Timestamp).toDate().isAfter(
                            DateTime.now(),
                          ),
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilot availability estimate',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(data['label'] as String? ?? 'Availability uncertain'),
                    const SizedBox(height: 8),
                    Text(
                      data['reason'] as String? ?? 'Ask faculty to confirm.',
                    ),
                    if (data['probability'] is num)
                      Text(
                        'Neighbour agreement: ${((data['probability'] as num) * 100).round()}% available. This is not validated accuracy.',
                      ),
                    for (final window in windows.take(2))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Suggested check-in window: ${time(window['startsAt'] as Timestamp)}–${time(window['endsAt'] as Timestamp)} Cebu time. Confirm first.',
                        ),
                      ),
                    if (windows.isNotEmpty)
                      const Text(
                        'Assumes the faculty member remains in the shared zone.',
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }
}
