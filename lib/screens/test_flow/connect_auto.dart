import 'package:flutter/material.dart';
import '../../models/test_result.dart';
import '../../services/pi_wifi_service.dart';
import '../../services/test_service.dart';

class ConnectAuto extends StatefulWidget {
  const ConnectAuto({super.key});

  @override
  State<ConnectAuto> createState() => _ConnectAutoState();
}

class _ConnectAutoState extends State<ConnectAuto> {
  final TextEditingController _ipController =
      TextEditingController(text: 'http://10.0.0.119:5000');

  final TestService _testService = TestService();

  bool _checkingHealth = false;
  bool _runningTest = false;
  bool _healthy = false;
  String _statusMessage = 'Enter Raspberry Pi IP and test connection.';
  PiTestResponse? _lastPiResponse;

  Future<void> _checkConnection() async {
    setState(() {
      _checkingHealth = true;
      _statusMessage = 'Checking Raspberry Pi connection...';
    });

    try {
      final service = PiWifiService(baseUrl: _ipController.text.trim());
      final ok = await service.checkHealth();

      setState(() {
        _healthy = ok;
        _statusMessage = ok
            ? 'Raspberry Pi is reachable.'
            : 'Raspberry Pi did not respond correctly.';
      });
    } catch (e) {
      setState(() {
        _healthy = false;
        _statusMessage = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _checkingHealth = false;
      });
    }
  }

  String _mapRisk(String rawResult) {
    final value = rawResult.toLowerCase().trim();

    if (value == 'strong') return 'HIGH';
    if (value == 'moderate') return 'WARNING';
    if (value == 'weak') return 'NORMAL';

    return rawResult.toUpperCase();
  }

  Future<void> _runTest() async {
    setState(() {
      _runningTest = true;
      _statusMessage = 'Running test on Raspberry Pi...';
    });

    try {
      final service = PiWifiService(baseUrl: _ipController.text.trim());
      final response = await service.runTest();

      final testResult = TestResult(
        createdAt: DateTime.tryParse(response.timestamp) ?? DateTime.now(),
        overallRisk: _mapRisk(response.result),
        biomarkers: {
          'calcium': response.intensity,
          'oxalate': 0.0,
          'ph': 0.0,
          'uricAcid': 0.0,
        },
        intensity: response.intensity,
        rawResult: response.result,
        imageUrl: response.imageUrl,
        imagePath: response.imagePath,
      );

      await _testService.saveTest(testResult);

      setState(() {
        _lastPiResponse = response;
        _statusMessage = 'Test completed and saved to Firestore.';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test saved successfully')),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Test failed: $e';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test failed: $e')),
      );
    } finally {
      setState(() {
        _runningTest = false;
      });
    }
  }

  Widget _buildResultCard() {
    final result = _lastPiResponse;
    if (result == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest Pi Result',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('Timestamp: ${result.timestamp}'),
            Text('Intensity: ${result.intensity.toStringAsFixed(2)}'),
            Text('Result: ${result.result}'),
            const SizedBox(height: 12),
            if (result.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  result.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Could not load image from Raspberry Pi'),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _checkingHealth || _runningTest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to ESBUDEN Device'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Raspberry Pi Base URL',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://10.0.0.119:5000',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: busy ? null : _checkConnection,
                    child: _checkingHealth
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Check Connection'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (!_healthy || busy) ? null : _runTest,
                    child: _runningTest
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Run Test'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _healthy
                    ? Colors.green.withOpacity(0.08)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_statusMessage),
            ),
            _buildResultCard(),
          ],
        ),
      ),
    );
  }
}