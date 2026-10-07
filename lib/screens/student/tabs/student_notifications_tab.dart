import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/auth_provider.dart';
import '../faculty_detail_screen.dart';

class StudentNotificationsTab extends ConsumerWidget {
  const StudentNotificationsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationOptInProvider);
    final inbox = ref.watch(notificationInboxProvider);
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Favorite faculty alerts'),
          subtitle: const Text(
            'Save alerts when a favorite has a fresh detection or changes shared zones while this app is open. No background push notifications.',
          ),
          value: enabled.value ?? false,
          onChanged: enabled.hasValue
              ? (value) async {
                  final uid = ref.read(authStateProvider).value?.uid;
                  if (uid == null) return;
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'facultyAlertsEnabled': value});
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not save alert preference. Retry.',
                          ),
                        ),
                      );
                    }
                  }
                }
              : null,
        ),
        Expanded(
          child: inbox.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(notificationInboxProvider),
                child: const Text('Could not load notifications. Retry'),
              ),
            ),
            data: (docs) => docs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No saved alerts. Enable alerts and favorite faculty members to receive future updates.',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data();
                      return ListTile(
                        leading: Icon(
                          data['read'] == true
                              ? Icons.notifications_none
                              : Icons.notifications_active_outlined,
                        ),
                        title: Text(
                          data['title'] as String? ?? 'Faculty update',
                        ),
                        subtitle: Text(data['message'] as String? ?? ''),
                        onTap: () async {
                          try {
                            await docs[i].reference.update({'read': true});
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not mark alert as read.',
                                  ),
                                ),
                              );
                            }
                          }
                          if (context.mounted && data['facultyId'] is String) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FacultyDetailScreen(
                                  facultyId: data['facultyId'] as String,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
