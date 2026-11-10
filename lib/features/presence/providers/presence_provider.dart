import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_provider.dart';
import '../models/presence_model.dart';
import '../services/presence_service.dart';

final presenceServiceProvider = Provider<PresenceService>(
  (ref) => PresenceService(),
);

/// The faculty's raw "Share my detected room" setting (`isVisible` on their
/// location document). Unlike the projection below this does not factor in
/// sharing hours, so the toggle shows what the faculty member actually set.
final sharingSettingProvider = StreamProvider.autoDispose.family<bool, String>((
  ref,
  uid,
) {
  return ref
      .watch(firestoreServiceProvider)
      .streamFacultyLocation(uid)
      .map((location) => location?.isVisible ?? true);
});

/// Student-readable faculty directory. This is the only collection students
/// can list, so it intentionally contains no email, device or enrollment data.
final facultyPresenceProvider = StreamProvider<List<FacultyPresence>>((ref) {
  return FirebaseFirestore.instance
      .collection(PresenceService.collection)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map(FacultyPresence.fromFirestore).toList();
        list.sort((a, b) => a.displayName.compareTo(b.displayName));
        return list;
      });
});

final facultyPresenceByIdProvider = Provider.family<FacultyPresence?, String>((
  ref,
  id,
) {
  final presence = ref.watch(facultyPresenceProvider);
  return presence.maybeWhen(
    data: (list) => list.where((f) => f.facultyId == id).firstOrNull,
    orElse: () => null,
  );
});
