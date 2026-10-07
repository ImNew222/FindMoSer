import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/ble_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/proximity_provider.dart';
import '../../widgets/faculty_card.dart';

class FindFacultyScreen extends ConsumerStatefulWidget {
  const FindFacultyScreen({super.key});
  @override
  ConsumerState<FindFacultyScreen> createState() => _FindFacultyScreenState();
}

class _FindFacultyScreenState extends ConsumerState<FindFacultyScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _department = 'All departments';
  bool _favoritesOnly = false;
  bool _availableOnly = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faculty = ref.watch(allFacultyLocationsProvider);
    final favorites = ref.watch(favoritesProvider).value ?? {};
    final departments = {
      'All departments',
      ...?faculty.value?.map((f) => f.department).where((d) => d.isNotEmpty),
    }.toList()..sort();
    final cached = ref.watch(locationCacheProvider);
    return Column(
      children: [
        if (cached)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Showing saved records while checking the connection. Locations may have changed.',
            ),
          ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find faculty',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  labelText: 'Name, department or zone',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: departments.contains(_department)
                        ? _department
                        : 'All departments',
                    items: departments
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (d) => setState(() => _department = d!),
                  ),
                  FilterChip(
                    label: const Text('Favorites'),
                    selected: _favoritesOnly,
                    onSelected: (v) => setState(() => _favoritesOnly = v),
                  ),
                  FilterChip(
                    label: const Text('Available'),
                    selected: _availableOnly,
                    onSelected: (v) => setState(() => _availableOnly = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: faculty.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: TextButton(
                onPressed: () {
                  ref.invalidate(locationSnapshotProvider);
                  ref.invalidate(allFacultyProvider);
                },
                child: const Text('Unable to load faculty. Retry'),
              ),
            ),
            data: (list) {
              final filtered = list
                  .where(
                    (f) =>
                        ('${f.displayName} ${f.department} ${f.location.publicZone}')
                            .toLowerCase()
                            .contains(_query) &&
                        (_department == 'All departments' ||
                            f.department == _department) &&
                        (!_favoritesOnly ||
                            favorites.contains(f.location.facultyId)) &&
                        (!_availableOnly ||
                            f.location.isVisible &&
                                f.user?.availability == 'available'),
                  )
                  .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No faculty match these filters.'),
                      TextButton(
                        onPressed: () => setState(() {
                          _query = '';
                          _search.clear();
                          _department = 'All departments';
                          _favoritesOnly = false;
                          _availableOnly = false;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: filtered.length,
                itemBuilder: (_, i) => FacultyCard(faculty: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}
