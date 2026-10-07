import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_routes.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/account_access.dart';
import '../faculty/faculty_dashboard.dart';
import '../student/student_dashboard.dart';
import 'restricted_account_screen.dart';

/// Every dashboard entry revalidates the account using server data. Cached data
/// can still be displayed inside an established session, but cannot unlock one.
class AccountAccessScreen extends ConsumerStatefulWidget {
  const AccountAccessScreen({super.key});
  @override
  ConsumerState<AccountAccessScreen> createState() =>
      _AccountAccessScreenState();
}

class _AccountAccessScreenState extends ConsumerState<AccountAccessScreen>
    with WidgetsBindingObserver {
  late Future<AccountAccess> _access;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _access = _verify();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  void _refresh() {
    if (_checking) return;
    setState(() {
      _access = _verify();
    });
  }

  Future<AccountAccess> _verify() async {
    _checking = true;
    try {
      final access = await ref.read(authServiceProvider).verifyCurrentSession();
      if (mounted) {
        // Registration can emit its auth event before the profile batch lands.
        // The server verification above has now refreshed Firestore's cache.
        ref.invalidate(currentUserProvider);
      }
      return access;
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AccountAccess>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
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
                      const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Account verification required',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Connect to the internet and sign in again. Your account must be verified before attendance is available.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error.toString(),
                        style: const TextStyle(color: AppTheme.error),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (_) => false,
                        ),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return switch (snapshot.requireData) {
        AccountAccess.student => const StudentDashboard(),
        AccountAccess.faculty => const FacultyDashboard(),
        final access => RestrictedAccountScreen(
          access: access,
          onRecheck: _refresh,
        ),
      };
    },
  );
}
