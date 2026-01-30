import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../services/bluetooth_service.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final bt = BleService();


  StreamSubscription? _scanSub;
  List<ScanResult> _results = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listenScanResults();
    _bootstrap();
  }

  void _listenScanResults() {
    _scanSub = bt.scanResults().listen((list) {
      // Optional: filter only ESBUDEN devices
      // final filtered = list.where((r) => r.device.advName.toUpperCase().contains('ESBUDEN')).toList();
      setState(() => _results = list);
    });
  }

  Future<void> _bootstrap() async {
    setState(() => _error = null);

    final supported = await bt.isSupported();
    if (!supported) {
      setState(() => _error = 'Bluetooth LE not supported on this device.');
      return;
    }

    await bt.ensurePermissions();
  }

  Future<void> _startScan() async {
    setState(() {
      _error = null;
      _scanning = true;
      _results = [];
    });

    try {
      await bt.startScan(timeout: const Duration(seconds: 8));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _scanning = false);
    }
  }

  Future<void> _connect(ScanResult r) async {
  setState(() => _error = null);
  try {
    await bt.stopScan();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Device detected ✅'),
        content: Text('Found ${_nameOf(r)}\n\n(We’ll add real connect next)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (e) {
    setState(() => _error = 'Action failed: $e');
  }
}

  String _nameOf(ScanResult r) {
    final n = r.device.advName.trim();
    if (n.isNotEmpty) return n;
    return r.device.remoteId.str;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BluetoothAdapterState>(
      stream: bt.adapterState(),
      builder: (context, snap) {
        final state = snap.data ?? BluetoothAdapterState.unknown;

        final isOn = state == BluetoothAdapterState.on;

        return Scaffold(
          appBar: AppBar(title: const Text('Add Device')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: const Text('Bluetooth'),
                    subtitle: Text('Status: ${state.name.toUpperCase()}'),
                    trailing: isOn
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.warning, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 12),

                if (!isOn) ...[
                  const Text(
                    'Turn on Bluetooth to search for ESBUDEN devices.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await bt.turnOn();
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enable Bluetooth from system settings.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Turn on Bluetooth'),
                  ),
                  const SizedBox(height: 12),
                ],

                if (isOn) ...[
                  FilledButton.icon(
                    onPressed: _scanning ? null : _startScan,
                    icon: const Icon(Icons.search),
                    label: Text(_scanning ? 'Scanning…' : 'Detect Devices'),
                  ),
                  const SizedBox(height: 12),

                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),

                  const SizedBox(height: 8),

                  Expanded(
                    child: _results.isEmpty
                        ? Center(
                            child: Text(
                              _scanning
                                  ? 'Detecting devices…'
                                  : 'No devices found yet.\nTap "Detect Devices".',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final r = _results[i];
                              final name = _nameOf(r);
                              final rssi = r.rssi;

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.bluetooth_connected),
                                  title: Text(name),
                                  subtitle: Text('RSSI: $rssi'),
                                  trailing: FilledButton(
                                    onPressed: () => _connect(r),
                                    child: const Text('Connect'),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
