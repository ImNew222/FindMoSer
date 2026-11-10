import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/user_model.dart';
import '../../features/auth/services/auth_service.dart';
import '../services/firestore_service.dart';

/// Singleton provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Singleton provider for FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

/// Stream provider for Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Provider that fetches the current user's full profile from Firestore
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) async {
      if (user == null) return null;
      final firestoreService = ref.read(firestoreServiceProvider);
      return firestoreService.getUserProfile(user.uid);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Stream provider for current user's profile (real-time)
final userProfileStreamProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      final firestoreService = ref.read(firestoreServiceProvider);
      return firestoreService.streamUserProfile(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});
