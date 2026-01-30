import 'package:flutter/material.dart';
import '../../models/test_result.dart';
import '../../services/test_service.dart';

class ResultsScreen extends StatelessWidget {
  final TestResult result;

  const ResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final biomarkers = result.biomarkers;

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: Text('Overall Risk: ${result.overallRisk}'),
                subtitle: Text('Source: ${result.source} • Device: ${result.deviceId ?? "-"}'),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Biomarker Analysis',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                children: biomarkers.entries.map((e) {
                  return Card(
                    child: ListTile(
                      title: Text(e.key),
                      trailing: Text('${e.value}'),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  await TestService().saveTest(result);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved to History ✅')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Save to History'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
