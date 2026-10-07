import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/account_access_screen.dart';

/// Named route definitions for FindMoSer navigation
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String studentDashboard = '/student-dashboard';
  static const String facultyDashboard = '/faculty-dashboard';
  static const String accountAccess = '/account-access';

  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    accountAccess: (context) => const AccountAccessScreen(),
    studentDashboard: (context) => const AccountAccessScreen(),
    facultyDashboard: (context) => const AccountAccessScreen(),
  };

  /// Smooth fade-through transition for all named route navigations
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder == null) return null;

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: curvedAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}
