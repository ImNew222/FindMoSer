import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/forecast_service.dart';

final researchConsentProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['researchConsent'] == true);
});

class PilotObservationPanel extends ConsumerStatefulWidget {
  const PilotObservationPanel({super.key});
  @override
  ConsumerState<PilotObservationPanel> createState() =>
      _PilotObservationPanelState();
}

class _PilotObservationPanelState extends ConsumerState<PilotObservationPanel> {
  bool _busy = false;
  String? _message;
  Future<void> _perform(
    Future<void> Function(String uid) action,
    String success,
  ) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action(uid);
      if (mounted) setState(() => _message = success);
    } catch (e) {
      if (mounted) {
        setState(
          () => _message =
              'Not saved: ${e.toString().replaceFirst('Bad state: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(researchConsentProvider);
    final db = FirebaseFirestore.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Participate in prediction pilot'),
          subtitle: const Text(
            'Optional. Save your confirmed availability, zone, time and schedule context. Used for the pilot model for up to 60 days. Turning this off stops collection and public estimates; it does not erase existing records.',
          ),
          value: consent.value ?? false,
          onChanged: _busy || !consent.hasValue
              ? null
              : (value) => _perform((uid) async {
                  await db.collection('users').doc(uid).update({
                    'researchConsent': value,
                  });
                  if (!value) {
                    await db
                        .collection('availability_forecasts')
                        .doc(uid)
                        .delete();
                  }
                }, 'Pilot preference saved.'),
        ),
        if (consent.value == true) ...[
          const Text(
            'Are you actually available for consultation right now? Record observations even when you are unavailable. One record per 30-minute interval; a later confirmation replaces that interval.',
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _perform(
                        (uid) =>
                            ForecastService(db).recordObservation(uid, true),
                        'Available observation saved.',
                      ),
                child: const Text('Yes, available'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _perform(
                        (uid) =>
                            ForecastService(db).recordObservation(uid, false),
                        'Unavailable observation saved.',
                      ),
                child: const Text('No, unavailable'),
              ),
            ],
          ),
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_message != null) Text(_message!),
        const SizedBox(height: 24),
      ],
    );
  }
}
