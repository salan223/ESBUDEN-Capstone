import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../routes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await AuthService().signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.authLanding,
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome 👋', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('UID: ${user?.uid ?? "Unknown"}'),
            Text('Email: ${user?.email ?? "Unknown"}'),
            Text('Name: ${user?.displayName ?? "Unknown"}'),
            const SizedBox(height: 20),
            const Text('Next steps:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• Add Firestore reads for this user profile'),
            const Text('• Build your real dashboard UI'),
            const Text('• Add navigation to History / Settings / Home'),
          ],
        ),
      ),
    );
  }
}
