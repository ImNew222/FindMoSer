import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/account_access.dart';
import '../../services/device_change_service.dart';
import '../../widgets/gradient_button.dart';

class RestrictedAccountScreen extends ConsumerStatefulWidget {
  final AccountAccess access;
  final VoidCallback onRecheck;
  const RestrictedAccountScreen({
    super.key,
    required this.access,
    required this.onRecheck,
  });
  @override
  ConsumerState<RestrictedAccountScreen> createState() =>
      _RestrictedAccountScreenState();
}

class _RestrictedAccountScreenState
    extends ConsumerState<RestrictedAccountScreen> {
  final _reason = TextEditingController();
  final _service = DeviceChangeService();
  bool _loading = false;
  String? _status;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.access == AccountAccess.deviceChangeRequired) _loadRequest();
  }

  Future<void> _loadRequest() async {
    try {
      final request = await _service.currentRequest();
      if (mounted) setState(() => _status = request?['status'] as String?);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Unable to load the request status. Check your connection.',
        );
      }
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await _service.requestChange(_reason.text);
      if (mounted) {
        setState(() {
          _status = 'pending';
          _message =
              'Request submitted. Ask the project team to verify your identity and approve the replacement.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceChange = widget.access == AccountAccess.deviceChangeRequired;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.neumorphicDecoration(borderRadius: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    deviceChange
                        ? Icons.phonelink_lock
                        : Icons.verified_user_outlined,
                    size: 44,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    deviceChange
                        ? 'Device approval required'
                        : 'Faculty approval required',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    deviceChange
                        ? 'This phone is not registered to your account, or your existing registration needs review. Attendance is unavailable until the project team verifies and approves this device.'
                        : 'Your faculty registration is pending verification. Ask the project team to approve your faculty access before opening attendance sessions.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    'Account ID: ${ref.read(authServiceProvider).currentUser?.uid ?? "unavailable"}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  if (deviceChange) ...[
                    const SizedBox(height: 20),
                    if (_status != null)
                      Text(
                        'Latest request: $_status',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (_status != 'pending') ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: AppTheme.neumorphicInsetDecoration(
                          borderRadius: 14,
                        ),
                        child: TextField(
                          controller: _reason,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Reason for device change',
                            hintText:
                                'For example: my registered phone was damaged.',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(
                        text: 'Request device approval',
                        onPressed: _loading ? null : _submit,
                        isLoading: _loading,
                        icon: Icons.send_outlined,
                      ),
                    ],
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : widget.onRecheck,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check approval'),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
