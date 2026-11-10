import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_theme.dart';
import '../../../core/campus_time.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/presence_provider.dart';
import '../services/location_policy.dart';

/// Faculty consultation status and room-sharing controls.
///
/// Saving here updates the faculty profile and the public presence projection,
/// so students immediately see the same availability and shared room.
class SharingSettings extends ConsumerStatefulWidget {
  const SharingSettings({super.key});
  @override
  ConsumerState<SharingSettings> createState() => _SharingSettingsState();
}

class _SharingSettingsState extends ConsumerState<SharingSettings> {
  bool _saving = false;
  bool _testing = false;

  Future<void> _save(Future<void> Function(String uid) action) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await action(uid);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not save settings: ${error.toString().replaceFirst('Bad state: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _hours(
    String uid, {
    String? currentStart,
    String? currentEnd,
  }) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _parse(currentStart) ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Sharing starts',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _parse(currentEnd) ?? const TimeOfDay(hour: 17, minute: 0),
      helpText: 'Sharing ends',
    );
    if (end == null || !mounted) return;
    String format(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (start == end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose different start and end times.')),
      );
      return;
    }
    await _save(
      (uid) => ref
          .read(presenceServiceProvider)
          .setSharingHours(uid, start: format(start), end: format(end)),
    );
  }

  TimeOfDay? _parse(String? value) {
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    return hour < 24 && minute < 60
        ? TimeOfDay(hour: hour, minute: minute)
        : null;
  }

  Future<void> _testDetection() async {
    if (_testing) return;
    setState(() => _testing = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 4),
        content: Text('Scanning for nearby classroom beacon...'),
      ),
    );
    try {
      final beacon = await ref.read(bleScannerProvider).scanOnce();
      if (!mounted) return;
      if (beacon == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No FindMoSer beacon detected. Ensure beacon is powered and close, or tap "Change room" to select manually.',
            ),
          ),
        );
      } else {
        final uid = ref.read(authStateProvider).value?.uid;
        if (uid != null) {
          await ref.read(firestoreServiceProvider).updateFacultyLocation(
            facultyId: uid,
            roomId: beacon.roomId,
            beaconId: beacon.deviceName,
          );
          await ref.read(presenceServiceProvider).sync(uid);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Text(
                'Updated to ${beacon.roomId} (${beacon.signalLabel}, ${beacon.rssi} dBm)!',
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _selectRoomManually(String uid, String currentRoom) async {
    final rooms = [
      'ComputerLab1',
      'ComputerLab2',
      'ComputerLab3',
      'ComputerLab4',
      'ComputerLab5',
      'DeanOffice',
      'Library',
      'Room101',
      'Room201',
      'Room301',
      'Room305',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Current Room',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Manually set your room or change it instantly for defense testing:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rooms.map((r) {
                  final isCurrent = r.toLowerCase() == currentRoom.toLowerCase();
                  return ChoiceChip(
                    label: Text(r),
                    selected: isCurrent,
                    onSelected: (val) {
                      if (val) Navigator.pop(ctx, r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (currentRoom.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => Navigator.pop(ctx, ''),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear current room'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _saving = true);
      try {
        if (selected.isEmpty) {
          await ref.read(firestoreServiceProvider).updateFacultyLocation(
            facultyId: uid,
            roomId: '',
            beaconId: '',
          );
        } else {
          await ref.read(firestoreServiceProvider).updateFacultyLocation(
            facultyId: uid,
            roomId: selected,
            beaconId: 'FindMoSer_$selected',
          );
        }
        await ref.read(presenceServiceProvider).sync(uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Text(
                selected.isEmpty
                    ? 'Room cleared.'
                    : 'Location updated to $selected!',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update room: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileStreamProvider).value;
    final presence = ref.watch(facultyPresenceProvider).value;
    final uid = user?.uid;
    final own = presence?.where((p) => p.facultyId == uid).firstOrNull;
    final setting = uid == null
        ? null
        : ref.watch(sharingSettingProvider(uid)).valueOrNull;
    final sharing = setting ?? own?.isSharing ?? true;
    final hoursGated =
        user != null &&
        sharing &&
        !LocationPolicy.withinHours(user, DateTime.now());
    const options = {
      'unset': 'Availability not set',
      'available': 'Available for consultation',
      'teaching': 'Teaching',
      'busy': 'Do not disturb',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sharing & consultation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Students see your availability and, when room sharing is on, the room where a classroom beacon detected you.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey('${user?.uid}-${user?.availability}-$_saving'),
          initialValue: options.containsKey(user?.availability)
              ? user!.availability
              : 'unset',
          decoration: const InputDecoration(labelText: 'Consultation status'),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: _saving
              ? null
              : (value) async {
                  if (value == null) return;
                  final messenger = ScaffoldMessenger.of(context);
                  await _save(
                    (uid) => ref
                        .read(presenceServiceProvider)
                        .setAvailability(uid, value),
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade800,
                      content: Text('Status updated: ${options[value] ?? value}'),
                    ),
                  );
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Share my detected room'),
          subtitle: Text(
            hoursGated
                ? 'On, but outside your sharing hours students see only your availability.'
                : 'Off hides your room from students. Your directory entry stays visible.',
          ),
          value: sharing,
          onChanged: _saving
              ? null
              : (value) => _save(
                  (uid) =>
                      ref.read(presenceServiceProvider).setSharing(uid, value),
                ),
        ),
        if (own != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'What students currently see',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  own.hasLocation
                      ? 'Room ${own.currentRoom}'
                      : own.isSharing
                      ? 'No room yet: this phone has not detected a classroom beacon.'
                      : 'Availability only; your room is hidden.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: own.hasLocation ? FontWeight.bold : FontWeight.normal,
                    color: own.hasLocation ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _saving || _testing ? null : _testDetection,
                      icon: _testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching, size: 16),
                      label: Text(_testing ? 'Scanning...' : 'Scan beacon'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving || _testing || uid == null
                          ? null
                          : () => _selectRoomManually(uid, own.currentRoom),
                      icon: const Icon(Icons.edit_location_alt, size: 16),
                      label: const Text('Change room'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: const Text('Sharing hours (Cebu time)'),
          subtitle: Text(
            user?.workStartTime?.isNotEmpty == true
                ? '${CampusTime.hhmm12(user!.workStartTime!)}–${CampusTime.hhmm12(user.workEndTime!)}'
                : 'No automatic cutoff configured',
          ),
          trailing: TextButton(
            onPressed: _saving || user == null
                ? null
                : () => _hours(
                    user.uid,
                    currentStart: user.workStartTime,
                    currentEnd: user.workEndTime,
                  ),
            child: const Text('Set'),
          ),
        ),
        const Text(
          'Outside these hours students see only your availability, not a room. Availability is set by you; a beacon detection never changes it.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        if (_saving) const LinearProgressIndicator(),
      ],
    );
  }
}
