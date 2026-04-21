import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/test_result.dart';
import '../../services/pi_wifi_service.dart';
import '../../services/test_service.dart';

class ConnectAuto extends StatefulWidget {
  const ConnectAuto({super.key});

  @override
  State<ConnectAuto> createState() => _ConnectAutoState();
}

class _ConnectAutoState extends State<ConnectAuto> {
  static const _savedBaseUrlKey = 'saved_pi_base_url';

  final TextEditingController _ipController = TextEditingController();
  final TestService _testService = TestService();

  bool _discovering = false;
  bool _checkingHealth = false;
  bool _runningTest = false;
  bool _healthy = false;

  String _statusMessage =
      'Searching for Uri-Track device. You can also enter the Pi URL manually.';

  PiTestResponse? _lastPiResponse;

  @override
  void initState() {
    super.initState();
    _loadSavedUrlOnly();
  }

  Future<void> _loadSavedUrlOnly() async {
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString(_savedBaseUrlKey);

  if (savedUrl != null && savedUrl.isNotEmpty) {
    _ipController.text = savedUrl;
    setState(() {
      _statusMessage = 'Loaded last used device URL.';
    });
  }
}

  Future<void> _saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedBaseUrlKey, url);
  }

  Future<void> _discoverPi() async {
    setState(() {
      _discovering = true;
      _healthy = false;
      _statusMessage = 'Searching for Uri-Track device on local Wi-Fi...';
    });

    try {
      final discoveredUrl = await PiWifiService.discoverPi();

      if (discoveredUrl == null) {
        setState(() {
          _statusMessage =
              'Could not find Uri-Track automatically. Enter the Pi URL manually, then tap Check Connection.';
        });
        return;
      }

      _ipController.text = discoveredUrl;
      await _saveBaseUrl(discoveredUrl);

      setState(() {
        _statusMessage = 'Device found successfully.';
      });

      await _checkConnection();
    } catch (e) {
      setState(() {
        _statusMessage = 'Discovery failed. Enter the Pi URL manually. Error: $e';
      });
    } finally {
      setState(() {
        _discovering = false;
      });
    }
  }

  Future<void> _checkConnection() async {
    final url = _ipController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _healthy = false;
        _statusMessage = 'Enter the Raspberry Pi URL first.';
      });
      return;
    }

    setState(() {
      _checkingHealth = true;
      _statusMessage = 'Checking Raspberry Pi connection...';
    });

    try {
      final service = PiWifiService(baseUrl: url);
      final ok = await service.checkHealth();

      setState(() {
        _healthy = ok;
        _statusMessage = ok
            ? 'Uri-Track device is connected and ready.'
            : 'The device is not responding correctly.';
      });

      if (ok) {
        await _saveBaseUrl(url);
      }
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

    if (value.contains('strong')) return 'HIGH';
    if (value.contains('moderate')) return 'WARNING';
    if (value.contains('weak')) return 'NORMAL';
    if (value.contains('no visible change')) return 'NORMAL';
    if (value.isEmpty) return 'UNKNOWN';

    return 'RESULT';
  }

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'NORMAL':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.length >= 15) {
      final y = timestamp.substring(0, 4);
      final m = timestamp.substring(4, 6);
      final d = timestamp.substring(6, 8);
      final hh = timestamp.substring(9, 11);
      final mm = timestamp.substring(11, 13);
      final ss = timestamp.substring(13, 15);
      return '$y-$m-$d  $hh:$mm:$ss';
    }
    return timestamp;
  }

  String _resultSummary(String rawResult) {
    if (rawResult.trim().isEmpty) {
      return 'The test completed, but the result could not be fully interpreted.';
    }
    return rawResult;
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
        createdAt: DateTime.now(),
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
      await _saveBaseUrl(_ipController.text.trim());

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

  Widget _buildStatusBanner() {
    final Color bgColor = _healthy
        ? Colors.green.withOpacity(0.10)
        : Colors.blueGrey.withOpacity(0.08);

    final Color textColor = _healthy ? Colors.green.shade800 : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _healthy ? Icons.check_circle : Icons.info_outline,
            color: _healthy ? Colors.green : Colors.blueGrey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  _healthy ? Colors.green.withOpacity(0.12) : Colors.grey.shade200,
              child: Icon(
                _healthy ? Icons.wifi : Icons.wifi_off,
                color: _healthy ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device Status',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _healthy ? 'Connected to Uri-Track' : 'Not connected',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ipController.text.trim().isEmpty
                        ? 'No URL entered'
                        : _ipController.text.trim(),
                    style: const TextStyle(color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _lastPiResponse;
    if (result == null) return const SizedBox.shrink();

    final risk = _mapRisk(result.result);
    final riskColor = _riskColor(risk);
    final intensityNormalized = result.intensity.clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Latest Test Result',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    risk,
                    style: TextStyle(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (result.valid)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'VALID TEST',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _resultSummary(result.result),
                style: const TextStyle(
                  height: 1.4,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 18),
            _infoTile(
              icon: Icons.access_time,
              label: 'Test Time',
              value: _formatTimestamp(result.timestamp),
            ),
            const SizedBox(height: 12),
            _infoTile(
              icon: Icons.analytics_outlined,
              label: 'Detected Intensity',
              value: result.intensity.toStringAsFixed(2),
            ),
            const SizedBox(height: 12),
            _infoTile(
              icon: Icons.compare_arrows,
              label: 'Change Detected',
              value: result.changeDetected ? 'Yes' : 'No',
            ),
            const SizedBox(height: 12),
            _infoTile(
              icon: Icons.view_stream_outlined,
              label: 'Detected Bands',
              value: result.detectedBandCount.toString(),
            ),
            const SizedBox(height: 12),
            _infoTile(
              icon: Icons.insights_outlined,
              label: 'Change Score',
              value: result.changeScore.toStringAsFixed(2),
            ),

            const SizedBox(height: 16),
            const Text(
              'Intensity Level',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: intensityNormalized,
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Captured Strip Image',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: Colors.grey.shade100,
                  child: result.imageUrl.isEmpty
                      ? const Center(child: Text('No image available'))
                      : Image.network(
                          result.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'Could not load image from device\n\n${result.imageUrl}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = _discovering || _checkingHealth || _runningTest;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Uri-Track Device'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildConnectionCard(),
            const SizedBox(height: 16),
            const Text(
              'Raspberry Pi Base URL',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://10.24.222.179:8000',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy ? null : _discoverPi,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _discovering
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Find Device'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: busy ? null : _checkConnection,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _checkingHealth
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Check Connection'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (!_healthy || busy) ? null : _runTest,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: _runningTest
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run Test'),
            ),
            const SizedBox(height: 16),
            _buildStatusBanner(),
            _buildResultCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}