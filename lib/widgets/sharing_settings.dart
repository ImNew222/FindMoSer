import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class SharingSettings extends ConsumerStatefulWidget {
  const SharingSettings({super.key});
  @override
  ConsumerState<SharingSettings> createState() => _SharingSettingsState();
}

class _SharingSettingsState extends ConsumerState<SharingSettings> {
  bool _saving = false;
  Future<void> _save(Map<String, dynamic> values) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(firestoreServiceProvider).updateUserProfile(uid, values);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save settings. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _hours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Sharing starts',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 17, minute: 0),
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
    await _save({'workStartTime': format(start), 'workEndTime': format(end)});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileStreamProvider).value;
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
          'Sharing & availability',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('${user?.uid}-${user?.availability}-$_saving'),
          initialValue: options.containsKey(user?.availability)
              ? user!.availability
              : 'unset',
          decoration: const InputDecoration(labelText: 'Consultation status'),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: _saving ? null : (value) => _save({'availability': value}),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: const Text('Sharing hours (Cebu time)'),
          subtitle: Text(
            user?.workStartTime?.isNotEmpty == true
                ? '${user!.workStartTime}–${user.workEndTime}'
                : 'No automatic cutoff configured',
          ),
          trailing: TextButton(
            onPressed: _saving ? null : _hours,
            child: const Text('Set'),
          ),
        ),
        const Text(
          'Students cannot see location or schedule details while sharing is paused or outside these hours. Availability is set by you; detection does not change it.',
        ),
        if (_saving) const LinearProgressIndicator(),
        const SizedBox(height: 24),
      ],
    );
  }
}
