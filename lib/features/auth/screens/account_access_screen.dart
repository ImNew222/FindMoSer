import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../services/account_access.dart';
import '../services/auth_service.dart';
import '../../faculty/screens/faculty_dashboard.dart';
import '../../attendance/screens/student/student_dashboard.dart';
import 'restricted_account_screen.dart';

/// Every cold start revalidates the account using server data. Cached data
/// cannot unlock a session: the server read and device-binding check are the
/// anti-spoofing boundary. Beacon detection and receipt submission keep
/// working offline once the session is unlocked; pending receipts queue on
/// this phone and revalidate against Firestore rules on sync.
///
/// Once a session is unlocked in this app run, a transient connectivity
/// failure on re-verification never discards the unlocked dashboard. The
/// screen keeps the last proven access, retries silently, and only falls
/// back to the gate for definitive failures (missing profile, deactivated
/// account, device mismatch). Firestore rules remain the authority.
class AccountAccessScreen extends ConsumerStatefulWidget {
  const AccountAccessScreen({super.key});
  @override
  ConsumerState<AccountAccessScreen> createState() =>
      _AccountAccessScreenState();
}

class _AccountAccessScreenState extends ConsumerState<AccountAccessScreen>
    with WidgetsBindingObserver {
  AccountAccess? _access;
  Object? _error;
  bool _checking = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verify();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _verify();
  }

  bool get _transientFailure => _error is SessionUnavailableException;

  Future<void> _verify() async {
    if (_checking) return;
    _checking = true;
    if (mounted) setState(() {});
    try {
      final access = await ref.read(authServiceProvider).verifyCurrentSession();
      if (mounted) {
        // Registration can emit its auth event before the profile batch lands.
        // The server verification above has now refreshed Firestore's cache.
        ref.invalidate(currentUserProvider);
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_access_$uid', access.name);
        }
        setState(() {
          _access = access;
          _error = null;
        });
      }
      _retryTimer?.cancel();
    } catch (error) {
      if (error is SessionUnavailableException && _access == null) {
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            final cached = prefs.getString('cached_access_$uid');
            if (cached != null) {
              final cachedAccess = AccountAccess.values
                  .where((a) => a.name == cached)
                  .firstOrNull;
              if (cachedAccess != null && mounted) {
                setState(() {
                  _access = cachedAccess;
                });
              }
            }
          } catch (_) {}
        }
      }
      if (mounted) setState(() => _error = error);
      // Keep probing for connectivity without user input. An unlocked
      // session stays on screen meanwhile; a cold session retries here too,
      // and losing the network between resumes no longer blocks the gate.
      _retryTimer?.cancel();
      _retryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!mounted) {
          _retryTimer?.cancel();
          return;
        }
        _verify();
      });
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    // An established session outlives a transient outage: connectivity
    // dropping between resumes shows the dashboard, not the gate.
    if (access != null) {
      return _dashboard(access);
    }
    if (_checking && access == null && _error == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      final transient = _transientFailure;
      return _gate(
        icon: transient ? Icons.wifi_off : Icons.lock_outline,
        title: transient ? 'Connect to the internet' : 'Account verification required',
        message: transient
            ? 'Sign-in stays active on this phone. Connecting automatically; '
                'attendance unlocks once the network is back.'
            : 'Connect to the internet and sign in again. Your account must '
                'be verified before attendance is available.',
        details: transient ? null : _error.toString(),
        action: transient ? 'Try again now' : 'Back to sign in',
        onAction: transient
            ? () => _verify()
            : () => Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _dashboard(AccountAccess access) => switch (access) {
    AccountAccess.student => const StudentDashboard(),
    AccountAccess.faculty => const FacultyDashboard(),
    final other => RestrictedAccountScreen(access: other, onRecheck: _verify),
  };

  Widget _gate({
    required IconData icon,
    required String title,
    required String message,
    String? details,
    required String action,
    required VoidCallback onAction,
  }) => Scaffold(
    backgroundColor: AppTheme.background,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.neumorphicDecoration(borderRadius: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: AppTheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(message),
                if (details != null) ...[
                  const SizedBox(height: 12),
                  Text(details, style: const TextStyle(color: AppTheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _checking ? null : onAction,
                  child: Text(action),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
