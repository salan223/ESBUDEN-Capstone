import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app_settings/app_settings.dart';

class ConnectAutoPage extends StatefulWidget {
  const ConnectAutoPage({super.key});

  @override
  State<ConnectAutoPage> createState() => _ConnectAutoPageState();
}

class _ConnectAutoPageState extends State<ConnectAutoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;

  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  // placeholders (later: load from Firestore/local storage)
  final String _lastDeviceName = 'ESBUDEN Device #4721';
  final String _lastUsed = 'Nov 15, 2025';

  String get _title {
    if (_adapterState == BluetoothAdapterState.off) return 'Bluetooth is off';
    if (_adapterState == BluetoothAdapterState.on) return 'Connecting to ESBUDEN...';
    return 'Checking Bluetooth...';
  }

  String get _subtitle {
    if (_adapterState == BluetoothAdapterState.off) {
      return 'Turn on Bluetooth to connect to your device.';
    }
    if (_adapterState == BluetoothAdapterState.on) {
      return 'Attempting to auto-connect to your last device.';
    }
    return 'Please wait...';
  }

  String get _hint {
    if (_adapterState == BluetoothAdapterState.off) return 'Bluetooth is disabled';
    if (_adapterState == BluetoothAdapterState.on) return 'Keep ESBUDEN device nearby';
    return 'Checking...';
  }

  bool get _isOn => _adapterState == BluetoothAdapterState.on;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _adapterSub = FlutterBluePlus.adapterState.listen((s) {
      if (!mounted) return;
      setState(() => _adapterState = s);

      if (s == BluetoothAdapterState.on) {
        _startAutoConnectFlow();
      } else {
        FlutterBluePlus.stopScan();
      }
    });

    FlutterBluePlus.adapterState.first.then((s) {
      if (!mounted) return;
      setState(() => _adapterState = s);
      if (s == BluetoothAdapterState.on) {
        _startAutoConnectFlow();
      }
    });
  }

  Future<void> _startAutoConnectFlow() async {
    // Later: scan + connect to last device
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
    } catch (_) {
      // ignore for now (permissions etc.)
    }
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Back'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 28),

              SizedBox(
                height: 220,
                width: 220,
                child: AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _RingsPainter(
                        progress: _ringCtrl.value,
                        enabled: _isOn,
                      ),
                      child: Center(
                        child: Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bluetooth,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              Text(
                _title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                    ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: _isOn ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _hint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Last connected device',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _lastDeviceName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Last used: $_lastUsed',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              if (!_isOn)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () {
                      AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: const Text(
                      'Turn on Bluetooth',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Device picker (wire later)')),
                    );
                  },
                  child: const Text('Connect to a different device'),
                ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.progress, required this.enabled});

  final double progress;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseOpacity = enabled ? 0.10 : 0.05;

    for (int i = 1; i <= 3; i++) {
      final t = (progress + (i * 0.18)) % 1.0;
      final radius = 40 + (t * 70);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = Colors.blue.withOpacity((1 - t) * baseOpacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.enabled != enabled;
  }
}
