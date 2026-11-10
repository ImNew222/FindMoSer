import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/widgets/glass_card.dart';

/// Shared attendance account settings for both roles.
class AccountProfilePanel extends ConsumerStatefulWidget {
  final bool faculty;
  final List<Widget> extraSections;
  const AccountProfilePanel({
    super.key,
    this.faculty = false,
    this.extraSections = const [],
  });
  @override
  ConsumerState<AccountProfilePanel> createState() =>
      _AccountProfilePanelState();
}

class _AccountProfilePanelState extends ConsumerState<AccountProfilePanel> {
  bool _busy = false;
  String? _error;

  Future<void> _editName(String uid, String oldName) async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initialName: oldName),
    );
    if (value == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(firestoreServiceProvider).updateUserProfile(uid, {
        'displayName': value,
      });
      if (mounted) {
        ref.invalidate(currentUserProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Display name updated. Existing receipts keep their recorded name.',
            ),
          ),
        );
      }
    } on FirebaseException catch (error) {
      final message = switch (error.code) {
        'permission-denied' =>
          'Your name change was refused (permission-denied). Contact the project administrator to check your profile permissions.',
        'unavailable' || 'deadline-exceeded' =>
          'Your name change could not be confirmed. Reconnect and check your profile before retrying.',
        'unauthenticated' => 'Please sign in again before changing your name.',
        'not-found' =>
          'Your account profile is missing. Contact the project administrator.',
        _ =>
          'Your name could not be updated (${error.code}). Please try again.',
      };
      _showNameError(message);
    } catch (_) {
      _showNameError('Your name could not be updated. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showNameError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Sign out failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileStreamProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your profile could not be loaded.'),
            TextButton(
              onPressed: () => ref.invalidate(userProfileStreamProvider),
              child: const Text('Retry'),
            ),
            TextButton(onPressed: _signOut, child: const Text('Sign out')),
          ],
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Sign in to view your profile.'));
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: AppTheme.neumorphicDecoration(borderRadius: 45),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 44,
                  color: AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.faculty ? 'Faculty' : 'Student'} • ${user.department}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(user.email),
                  const SizedBox(height: 10),
                  const Text(
                    'Account ID',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  SelectableText(user.uid),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _editName(user.uid, user.displayName),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit name'),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: user.uid),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account ID copied.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copy ID'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.faculty ? 'Faculty access' : 'Device binding',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.faculty
                        ? 'Attendance management requires an approved faculty account. Contact the project administrator for account access changes.'
                        : 'Your student account is linked to your Android device. On a replacement phone, sign in and submit a device-change request. The project administrator must approve it before attendance is available.',
                  ),
                ],
              ),
            ),
            for (final section in widget.extraSections) ...[
              const SizedBox(height: 16),
              GlassCard(child: section),
            ],
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About ${AppConstants.appName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Proximity-based classroom attendance'),
                  const Text(AppConstants.schoolName),
                  const Text('Version ${AppConstants.appVersion}'),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: Text(_busy ? 'Please wait…' : 'Sign out'),
            ),
          ],
        );
      },
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initialName;
  const _NameDialog({required this.initialName});
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit display name'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Name'),
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Enter your name.' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}
