import 'package:flutter/material.dart';

import 'screens/auth/auth_landing.dart';
import 'screens/auth/login.dart';
import 'screens/auth/signup.dart';
import 'screens/home/dashboard.dart';
import 'screens/history/history_reports.dart';
import 'screens/test_flow/connect_auto.dart';
import 'screens/reports/reports_page.dart';
import 'screens/test_flow/connection_troubleshooting.dart';

class Routes {
  static const authLanding = '/';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const btTroubleshoot = '/bt/troubleshoot';


  // Test flow
  static const connectAuto = '/test/connect';

  // History (chart + filters + past tests list)
  static const historyReports = '/history';

  // Reports (medical report + export PDF)
  static const reports = '/reports';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.authLanding: (_) => const AuthLandingScreen(),
  Routes.login: (_) => const LoginScreen(),
  Routes.signup: (_) => const SignupScreen(),
  Routes.dashboard: (_) => const DashboardScreen(),

  Routes.connectAuto: (_) => const ConnectAutoPage(),
  Routes.historyReports: (_) => const HistoryReportsPage(),
  Routes.reports: (_) => const ReportsPage(),
  Routes.btTroubleshoot: (_) => const ConnectionTroubleshootingPage(),

};
