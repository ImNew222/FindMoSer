import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../../core/app_theme.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_routes.dart';
import '../../../shared/providers/auth_provider.dart';

/// Splash screen with Lottie animation and neumorphic branding
///
/// Checks auth state and redirects to login or appropriate dashboard.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(
      const Duration(milliseconds: AppConstants.splashDurationMs),
    );

    if (!mounted) return;

    // Check auth state
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) => _navigateForUser(user),
      loading: () {
        // Auth stream still loading -- check cached user directly.
        // Firebase Auth persists the user locally, so currentUser
        // is available even offline after a first login.
        final cachedUser = ref.read(authServiceProvider).currentUser;
        _navigateForUser(cachedUser);
      },
      error: (_, __) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      },
    );
  }

  Future<void> _navigateForUser(User? user) async {
    if (user == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      return;
    }

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.accountAccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppTheme.background,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ─── Lottie Location Pin Animation ───
              SizedBox(
                    width: 200,
                    height: 200,
                    child: Lottie.asset(
                      'assets/animations/splash_location.json',
                      fit: BoxFit.contain,
                      repeat: true,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .scaleXY(begin: 0.8, end: 1.0, duration: 800.ms),

              const SizedBox(height: 40),

              // ─── App Name (neumorphic text) ───
              Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    decoration: AppTheme.neumorphicDecoration(
                      borderRadius: 24,
                      blurRadius: 12,
                    ),
                    child: Text(
                      'FindMoSer',
                      style: GoogleFonts.inter(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                  )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, duration: 600.ms),

              const SizedBox(height: 14),

              // ─── Tagline ───
              Text(
                    AppConstants.appTagline,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  )
                  .animate(delay: 1000.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, duration: 500.ms),

              const Spacer(flex: 3),

              // ─── School Name ───
              Text(
                AppConstants.schoolName,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textHint,
                ),
              ).animate(delay: 1200.ms).fadeIn(duration: 400.ms),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
