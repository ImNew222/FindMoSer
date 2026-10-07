import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final favoritesProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(<String>{});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(
        (doc) =>
            Set<String>.from(doc.data()?['favoriteFacultyIds'] as List? ?? []),
      );
});

Future<void> toggleFavorite(WidgetRef ref, String facultyId) async {
  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) throw StateError('Sign in to save favorites.');
  final favorites = ref.read(favoritesProvider).value ?? {};
  await FirebaseFirestore.instance.collection('users').doc(uid).update({
    'favoriteFacultyIds': favorites.contains(facultyId)
        ? FieldValue.arrayRemove([facultyId])
        : FieldValue.arrayUnion([facultyId]),
  });
}
