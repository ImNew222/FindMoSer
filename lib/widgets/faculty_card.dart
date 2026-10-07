import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_theme.dart';
import '../providers/ble_provider.dart';
import '../providers/favorites_provider.dart';
import '../services/location_policy.dart';
import '../screens/student/faculty_detail_screen.dart';

class FacultyCard extends ConsumerWidget {
  final FacultyLocationWithName faculty;
  final int animationIndex;
  const FacultyCard({
    super.key,
    required this.faculty,
    this.animationIndex = 0,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved =
        ref
            .watch(favoritesProvider)
            .value
            ?.contains(faculty.location.facultyId) ==
        true;
    final shared = faculty.location.isVisible;
    final fresh = faculty.status == FacultyStatus.online;
    final status = !shared
        ? 'Not shared'
        : fresh
        ? 'Recent detection'
        : 'Last known';
    final color = fresh ? AppTheme.success : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: DecoratedBox(
        decoration: AppTheme.neumorphicDecoration(
          borderRadius: 20,
          intensity: 0.4,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    FacultyDetailScreen(facultyId: faculty.location.facultyId),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: AppTheme.primary,
                        child: Text(
                          faculty.displayName.isEmpty
                              ? '?'
                              : faculty.displayName[0].toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              faculty.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              faculty.department,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: saved ? 'Remove favorite' : 'Save favorite',
                        onPressed: () async {
                          try {
                            await toggleFavorite(
                              ref,
                              faculty.location.facultyId,
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not save favorite. Try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: Icon(
                          saved
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        shared
                            ? Icons.location_on_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shared
                              ? '${faculty.location.publicZone} · $status'
                              : 'Location not shared',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (shared)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Detected ${faculty.location.timeAgo.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  if (shared && faculty.user != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        LocationPolicy.availabilityLabel(
                          faculty.user!.availability,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
