import 'package:flutter/material.dart';

import '../../models/test_result.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import '../test_flow/results.dart';
import '../bluetooth/device_scan.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final testService = TestService();

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
            Text(
              'Welcome 👋',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('UID: ${user?.uid ?? "Unknown"}'),
            Text('Email: ${user?.email ?? "Unknown"}'),
            Text('Name: ${user?.displayName ?? "Unknown"}'),
            const SizedBox(height: 16),

            // Latest test
            StreamBuilder<TestResult?>(
              stream: testService.watchLatestTest(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: ListTile(
                      title: Text('Latest Result'),
                      subtitle: Text('Loading...'),
                    ),
                  );
                }

                final latest = snapshot.data;
                if (latest == null) {
                  return const Card(
                    child: ListTile(
                      title: Text('No tests yet'),
                      subtitle: Text(
                        'Tap "Add Demo Test" to create your first result.',
                      ),
                    ),
                  );
                }

                final ox = latest.biomarkers['oxalate'];
                final ph = latest.biomarkers['ph'];
                final protein = latest.biomarkers['protein'];

                final dateStr = latest.createdAt == null
                    ? 'Unknown time'
                    : '${latest.createdAt!.year}-${latest.createdAt!.month.toString().padLeft(2, '0')}-${latest.createdAt!.day.toString().padLeft(2, '0')}';

                return Card(
                  child: ListTile(
                    title: Text('Latest: ${latest.overallRisk}'),
                    subtitle: Text(
                      'Oxalate: $ox • pH: $ph • Protein: $protein\n$dateStr • Source: ${latest.source}',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await testService.addDemoTest();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo test saved ✅')),
                  );
                },
                child: const Text('Add Demo Test'),
              ),
            ),

            const SizedBox(height: 12),

            // (Optional) placeholder button for later history screen routes
            // Only keep this if you add Routes.history later.
            OutlinedButton(
              onPressed: () {
                final demo = TestService().generateDemoResult();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultsScreen(result: demo),
                  ),
                );
              },
              child: const Text('Preview Demo Result'),
            ),

            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceScanScreen()),
                );
              },
              icon: const Icon(Icons.bluetooth),
              label: const Text('Add Device'),
            ),
          ],
        ),
      ),
    );
  }
}
