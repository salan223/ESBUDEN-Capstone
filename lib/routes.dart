import 'package:flutter/material.dart';

import 'screens/auth/auth_landing.dart';
import 'screens/auth/login.dart';
import 'screens/auth/signup.dart';
import 'screens/home/dashboard.dart';

import 'screens/test_flow/connect_auto.dart';
import 'screens/test_flow/connection_troubleshooting.dart';

class Routes {
  static const authLanding = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';

  // Test flow
  static const connectAuto = '/test/connect';
  static const btTroubleshoot = '/test/connect/troubleshoot';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.authLanding: (_) => const AuthLandingScreen(),
  Routes.login: (_) => const LoginScreen(),
  Routes.signup: (_) => const SignupScreen(),
  Routes.dashboard: (_) => const DashboardScreen(),

  // Test flow
  Routes.connectAuto: (_) => const ConnectAutoPage(),
  Routes.btTroubleshoot: (_) => const ConnectionTroubleshootingPage(),
};
