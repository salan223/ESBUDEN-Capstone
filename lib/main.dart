import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EsbudenApp());
}

class EsbudenApp extends StatelessWidget {
  const EsbudenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESBUDEN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F80ED)),
        scaffoldBackgroundColor: const Color(0xFFF7F9FB),
      ),
      initialRoute: Routes.authLanding,
      routes: appRoutes,
    );
  }
}

/// ROUTES (simple for now — later we’ll split into routes.dart)
class Routes {
  static const authLanding = '/auth';
  static const login = '/login';
  static const signup = '/signup';

  static const dashboard = '/dashboard';

  static const connectAuto = '/test/connect';
  static const devicePicker = '/test/devices';
  static const insertStrip = '/test/insert';
  static const scanning = '/test/scanning';
  static const results = '/test/results';

  static const history = '/history';
  static const reportDetail = '/report';
  static const settings = '/settings';
}

final Map<String, WidgetBuilder> appRoutes = {
  Routes.authLanding: (_) => const AuthLandingScreen(),
  Routes.login: (_) => const LoginScreen(),
  Routes.signup: (_) => const SignupScreen(),

  Routes.dashboard: (_) => const DashboardScreen(),

  Routes.connectAuto: (_) => const ConnectAutoScreen(),
  Routes.devicePicker: (_) => const DevicePickerScreen(),
  Routes.insertStrip: (_) => const InsertStripScreen(),
  Routes.scanning: (_) => const ScanningScreen(),
  Routes.results: (_) => const ResultsScreen(),

  Routes.history: (_) => const HistoryReportsScreen(),
  Routes.reportDetail: (_) => const ReportDetailScreen(),
  Routes.settings: (_) => const SettingsScreen(),
};

/// --------------------
/// SCREENS (placeholders)
/// Later we’ll move each into its own file under lib/screens/
/// --------------------

class AuthLandingScreen extends StatelessWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.health_and_safety, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Welcome to ESBUDEN',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Early kidney-stone detection and biomarker tracking.\nLog in to sync your history and reports.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.3, color: Colors.black54),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, Routes.signup),
                child: const Text('Sign Up'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, Routes.login),
                child: const Text('Log In'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, Routes.dashboard),
                child: const Text('Continue as Guest'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Guest mode won’t save history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: const Center(child: Text('Login UI (Firebase) next')),
    );
  }
}

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: const Center(child: Text('Signup UI (Firebase) next')),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: ListTile(
                title: Text('Last Result'),
                subtitle: Text('Normal • Jan 20, 2026'),
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.connectAuto),
              child: const Text('Start New Test'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, Routes.history),
              child: const Text('History & Reports'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.settings),
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class ConnectAutoScreen extends StatelessWidget {
  const ConnectAutoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connecting…')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Attempting to auto-connect to your last ESBUDEN device…'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.devicePicker),
              child: const Text('Select Device'),
            ),
          ],
        ),
      ),
    );
  }
}

class DevicePickerScreen extends StatelessWidget {
  const DevicePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Device')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('ESBUDEN-001'),
              subtitle: const Text('Available'),
              trailing: FilledButton(
                onPressed: () => Navigator.pushNamed(context, Routes.insertStrip),
                child: const Text('Connect'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InsertStripScreen extends StatelessWidget {
  const InsertStripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insert Test Strip')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.receipt_long, size: 72),
            const SizedBox(height: 12),
            const Text(
              'Insert the strip with the reagent pad facing upward.\nMake sure it is fully inserted.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.scanning),
              child: const Text('Start Scan'),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanningScreen extends StatelessWidget {
  const ScanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analyzing…')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Analyzing sample… (~5 seconds)'),
            const SizedBox(height: 12),
            const Text('• Reading color intensity\n• Calibrating sensor\n• Extracting biomarkers'),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.results),
              child: const Text('Finish (Demo)'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: ListTile(
                title: Text('Overall Risk'),
                subtitle: Text('NORMAL'),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                title: Text('Oxalate'),
                subtitle: Text('Slightly Elevated'),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, Routes.history),
              child: const Text('View History'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryReportsScreen extends StatelessWidget {
  const HistoryReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History & Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Jan 20, 2026'),
            subtitle: const Text('Normal'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.reportDetail),
          ),
          ListTile(
            title: const Text('Jan 14, 2026'),
            subtitle: const Text('Warning'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.reportDetail),
          ),
        ],
      ),
    );
  }
}

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Report')),
      body: const Center(child: Text('Detailed report screen next')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings UI next')),
    );
  }
}
