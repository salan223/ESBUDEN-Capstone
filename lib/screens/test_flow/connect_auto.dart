import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app_settings/app_settings.dart';

import 'package:esbuden_app/routes.dart'; // ✅ for Routes.btTroubleshoot

class ConnectAutoPage extends StatefulWidget {
  const ConnectAutoPage({super.key});

  @override
  State<ConnectAutoPage> createState() => _ConnectAutoPageState();
}

class _ConnectAutoPageState extends State<ConnectAutoPage> {
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final Map<String, ScanResult> _seen = {};
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingId;

  bool get _btOn => _adapterState == BluetoothAdapterState.on;

  @override
  void initState() {
    super.initState();

    _adapterSub = FlutterBluePlus.adapterState.listen((s) async {
      if (!mounted) return;
      setState(() => _adapterState = s);

      if (s == BluetoothAdapterState.on) {
        await _startScan();
      } else {
        await _stopScan();
      }
    });

    FlutterBluePlus.adapterState.first.then((s) async {
      if (!mounted) return;
      setState(() => _adapterState = s);
      if (s == BluetoothAdapterState.on) {
        await _startScan();
      }
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _adapterSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _stopScan() async {
    _scanSub?.cancel();
    _scanSub = null;

    if (_isScanning) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }

    _isScanning = false;
    if (mounted) setState(() {});
  }

  Future<void> _startScan() async {
    if (!_btOn) return;

    _seen.clear();

    await _stopScan();
    _isScanning = true;
    if (mounted) setState(() {});

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;
      for (final r in results) {
        final id = r.device.remoteId.str;
        _seen[id] = r;
        changed = true;
      }
      if (changed && mounted) setState(() {});
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
    } catch (_) {
      // permissions / settings issues
    } finally {
      _isScanning = false;
      if (mounted) setState(() {});
    }
  }

  // Filter only ESBUDEN devices (change if your device advertises differently)
  List<ScanResult> get _esbudenResults {
    final list = _seen.values.where((r) {
      final name = r.device.platformName.trim();
      return name.toUpperCase().contains('ESBUDEN');
    }).toList();

    list.sort((a, b) => b.rssi.compareTo(a.rssi));
    return list;
  }

  int _signalPercent(int rssi) {
    final clamped = rssi.clamp(-100, -40);
    final pct = ((clamped + 100) / 60.0) * 100.0;
    return pct.round().clamp(0, 100);
  }

  Future<void> _connect(ScanResult r) async {
    if (_isConnecting) return;

    final device = r.device;
    final id = device.remoteId.str;

    setState(() {
      _isConnecting = true;
      _connectingId = id;
    });

    await _stopScan();

    try {
      // best-effort cleanup
      try {
        await device.disconnect();
      } catch (_) {}

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.platformName} ✅')),
      );

      setState(() {
        _isConnecting = false;
        _connectingId = null;
      });

      // TODO: navigate to next step in your flow
      // Navigator.pushReplacementNamed(context, Routes.insertStrip);

    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isConnecting = false;
        _connectingId = null;
      });

      await _startScan();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _esbudenResults;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Back'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),

              Text(
                'Select Device',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose an ESBUDEN device to connect.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
              ),

              const SizedBox(height: 16),

              if (!_btOn)
                _InfoBanner(
                  text: 'Bluetooth is off. Turn it on to scan.',
                  actionText: 'Turn on',
                  isLoading: false,
                  onTap: () => AppSettings.openAppSettings(
                    type: AppSettingsType.bluetooth,
                  ),
                )
              else
                _InfoBanner(
                  text: _isScanning ? 'Scanning for devices…' : 'Scan complete',
                  actionText: 'Rescan',
                  isLoading: _isScanning, // ✅ spinner while scanning
                  onTap: _startScan,
                ),

              const SizedBox(height: 14),

              Expanded(
                child: ListView(
                  children: [
                    if (_btOn && devices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _isScanning
                              ? 'No ESBUDEN devices found yet…'
                              : 'No ESBUDEN devices found. Make sure it’s on and nearby.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                      ),

                    ...devices.map((r) {
                      final name = r.device.platformName.trim().isEmpty
                          ? 'ESBUDEN Device'
                          : r.device.platformName.trim();
                      final pct = _signalPercent(r.rssi);
                      final isThisConnecting =
                          _connectingId == r.device.remoteId.str;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _DeviceCard(
                          name: name,
                          percent: pct,
                          isConnecting: isThisConnecting,
                          onConnect: (_btOn && !_isConnecting)
                              ? () => _connect(r)
                              : null,
                        ),
                      );
                    }),

                    const SizedBox(height: 6),
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection Tips',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            const _Tip('Ensure your device is powered on'),
                            const _Tip('Keep device within 10 feet (3 meters)'),
                            const _Tip('Make sure Bluetooth is enabled on your phone'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ✅ Opens troubleshooting, then auto-rescans on return
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          final shouldRescan = await Navigator.pushNamed(
                            context,
                            Routes.btTroubleshoot,
                          );

                          if (!mounted) return;

                          if (shouldRescan == true && _btOn) {
                            await _startScan();
                          }
                        },
                        child: const Text('Having trouble connecting?'),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.text,
    required this.actionText,
    required this.isLoading,
    required this.onTap,
  });

  final String text;
  final String actionText;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // ✅ Always animates: indeterminate spinner
            if (isLoading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(Icons.autorenew, color: primary),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),

            Text(
              actionText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.name,
    required this.percent,
    required this.isConnecting,
    required this.onConnect,
  });

  final String name;
  final int percent;
  final bool isConnecting;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.bluetooth,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SignalBars(percent: percent),
                      const SizedBox(width: 8),
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: onConnect,
                child: Text(
                  isConnecting ? 'Connecting...' : 'Connect',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.percent});
  final int percent;

  int get bars {
    if (percent >= 80) return 4;
    if (percent >= 60) return 3;
    if (percent >= 40) return 2;
    if (percent >= 20) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(bool on) => Container(
          width: 6,
          height: on ? 14 : 10,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: on ? Theme.of(context).colorScheme.primary : Colors.black12,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    return Row(
      children: [
        bar(bars >= 1),
        bar(bars >= 2),
        bar(bars >= 3),
        bar(bars >= 4),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
