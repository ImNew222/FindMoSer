import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'ble_provider.dart';
import 'favorites_provider.dart';

final notificationOptInProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['facultyAlertsEnabled'] == true);
});
final notificationInboxProvider =
    StreamProvider<List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
      final uid = ref.watch(authStateProvider).value?.uid;
      if (uid == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs);
    });

/// In-app subscription only. No background push claim. First snapshot establishes
/// a baseline; only subsequent fresh/zone transitions generate a stored event.
final notificationCollectorProvider = Provider.autoDispose<void>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  final enabled = ref.watch(notificationOptInProvider).value == true;
  final favorites = ref.watch(favoritesProvider).value ?? <String>{};
  if (uid == null || !enabled) return;
  Map<String, String>? baseline;
  ref.listen(allFacultyLocationsProvider, (previous, next) {
    if (!next.hasValue || ref.read(locationCacheProvider)) return;
    final current = <String, String>{};
    for (final f in next.value!) {
      final id = f.location.facultyId;
      if (!favorites.contains(id)) continue;
      final fresh = f.status == FacultyStatus.online && f.location.isVisible;
      final signature = fresh ? f.location.publicZone : '';
      current[id] = signature;
      if (baseline != null &&
          signature.isNotEmpty &&
          baseline![id] != signature) {
        final eventId = '${id}_${f.location.timestamp.millisecondsSinceEpoch}';
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(eventId)
            .set({
              'facultyId': id,
              'title': '${f.displayName} has a recent shared detection',
              'createdAt': FieldValue.serverTimestamp(), 'read': false,
              // Deliberately do not persist a zone or room in an inbox: sharing can be revoked later.
              'message':
                  'Open the faculty details to check current sharing, zone and availability.',
            })
            .catchError((Object _) {
              /* Next transitions remain usable if a write fails. */
            });
      }
    }
    baseline = current;
  }, fireImmediately: true);
});
