import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../services/roster_service.dart';

final _rosterServiceProvider = Provider((ref) => RosterService());

Future<void> showRosterSheet(
  BuildContext context, {
  required String facultyId,
  required String classId,
  required String subject,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppTheme.background,
  builder: (_) => RosterSheet(
    facultyId: facultyId,
    classId: classId,
    subject: subject,
  ),
);

class RosterSheet extends ConsumerStatefulWidget {
  final String facultyId;
  final String classId;
  final String subject;
  const RosterSheet({
    super.key,
    required this.facultyId,
    required this.classId,
    required this.subject,
  });
  @override
  ConsumerState<RosterSheet> createState() => _RosterSheetState();
}

class _RosterSheetState extends ConsumerState<RosterSheet> {
  String _search = '';

  void _showAddDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Add student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'School Student ID',
                hintText: 'e.g. 2023-00123',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Student name',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final id = idController.text.trim();
              final name = nameController.text.trim();
              if (id.isEmpty || name.isEmpty) return;
              try {
                await ref.read(_rosterServiceProvider).addRosterEntry(
                  facultyId: widget.facultyId,
                  classId: widget.classId,
                  schoolId: id,
                  studentName: name,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCSVDialog() {
    final csvController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Import CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste CSV content below.\nFormat: School ID, Student Name (one per line)',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: csvController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '2023-00123, Juan Dela Cruz\n2023-00456, Maria Santos',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final csv = csvController.text.trim();
              if (csv.isEmpty) return;
              final service = ref.read(_rosterServiceProvider);
              final entries = service.parseCSV(csv);
              if (entries.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('No valid entries found in CSV.'),
                    ),
                  );
                }
                return;
              }
              try {
                final count = await service.importRoster(
                  facultyId: widget.facultyId,
                  classId: widget.classId,
                  entries: entries,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Imported $count student(s).')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(RosterEntry entry) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Text('Remove student'),
        content: Text(
          'Remove ${entry.studentName} (${entry.schoolId}) from the roster?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () async {
              try {
                await ref.read(_rosterServiceProvider).deleteRosterEntry(
                  facultyId: widget.facultyId,
                  classId: widget.classId,
                  schoolId: entry.schoolId,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * .85 - keyboard)
        .clamp(200.0, 800.0);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Class Roster',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subject,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showAddDialog,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Add manually'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showCSVDialog,
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('Import CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search roster',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => _search = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                // Roster list
                Expanded(
                  child: StreamBuilder<List<RosterEntry>>(
                    stream: ref.watch(_rosterServiceProvider).streamRoster(
                      widget.facultyId,
                      widget.classId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Could not load roster.'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final all = snapshot.data!;
                      final linked =
                          all.where((e) => e.status == 'linked').length;
                      final pending =
                          all.where((e) => e.status == 'pending').length;
                      final filtered = _search.isEmpty
                          ? all
                          : all
                              .where((e) =>
                                  e.studentName
                                      .toLowerCase()
                                      .contains(_search) ||
                                  e.schoolId
                                      .toLowerCase()
                                      .contains(_search))
                              .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration:
                                AppTheme.neumorphicInsetDecoration(
                                  borderRadius: 12,
                                ),
                            child: Row(
                              children: [
                                _summaryChip(
                                  '$linked linked',
                                  const Color(0xFF4CAF50),
                                ),
                                const SizedBox(width: 14),
                                _summaryChip(
                                  '$pending pending',
                                  const Color(0xFFFFA726),
                                ),
                                const Spacer(),
                                Text(
                                  '${all.length} total',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (filtered.isEmpty)
                            const Expanded(
                              child: Center(
                                child: Text(
                                  'No students in the roster yet.\nAdd manually or import from CSV.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final entry = filtered[i];
                                  return _rosterTile(entry);
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _rosterTile(RosterEntry entry) {
    final isLinked = entry.status == 'linked';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: isLinked
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFFA726),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(entry.studentName),
      subtitle: Text(
        '${entry.schoolId}${isLinked ? ' - Linked' : ' - Pending'}',
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
      trailing: IconButton(
        tooltip: 'Remove from roster',
        onPressed: () => _confirmDelete(entry),
        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
      ),
    );
  }
}
