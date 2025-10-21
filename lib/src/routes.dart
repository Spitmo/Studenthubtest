import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/auth/registration_screen.dart';
import 'screens/student/student_shell.dart';
import 'screens/admin/admin_dashboard.dart';

class Routes {
  static const initial = '/';
  static const login = '/login';
  static const register = '/register';
  static const student = '/student';
  static const admin = '/admin';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case initial:
      case login:
        return _fade(const LoginScreen());
      case register:
        return _fade(const RegistrationScreen());
      case student:
        return _fade(const StudentShell());
      case admin:
        return _fade(const AdminDashboardScreen());
      default:
        return MaterialPageRoute(
            builder: (_) => const Scaffold(body: Center(child: Text('Not found'))));
    }
  }

  static PageRoute _fade(Widget child) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => _AuthGate(child: child),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      );
}

class _AuthGate extends StatelessWidget {
  final Widget child;
  const _AuthGate({required this.child});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (child is LoginScreen || child is RegistrationScreen) return child;
    if (!auth.isLoggedIn) return const LoginScreen();

    if (child is StudentShell && auth.role != UserRole.student) {
      return const LoginScreen();
    }
    if (child is AdminDashboardScreen && auth.role != UserRole.admin) {
      return const LoginScreen();
    }
    return child;
  }
}


