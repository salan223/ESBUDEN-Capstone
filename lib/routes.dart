import 'package:flutter/material.dart';

import 'screens/auth/auth_landing.dart';
import 'screens/auth/login.dart';
import 'screens/auth/signup.dart';
import 'screens/home/dashboard.dart';

// ✅ FIXED: correct path
import 'screens/test_flow/connect_auto.dart';

class Routes {
  static const authLanding = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';

  // ✅ Start New Test -> Bluetooth connect screen
  static const connectAuto = '/test/connect';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.authLanding: (_) => const AuthLandingScreen(),
  Routes.login: (_) => const LoginScreen(),
  Routes.signup: (_) => const SignupScreen(),
  Routes.dashboard: (_) => const DashboardScreen(),

  // ✅ IMPORTANT: the widget class inside connect_auto.dart must be ConnectAutoPage
  Routes.connectAuto: (_) => const ConnectAutoPage(),
};
