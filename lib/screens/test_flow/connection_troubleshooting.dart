import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';

class ConnectionTroubleshootingPage extends StatelessWidget {
  const ConnectionTroubleshootingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      'Connection Troubleshooting',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Follow these steps to resolve connection issues with your ESBUDEN device.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 18),

                    const _StepCard(
                      step: 1,
                      icon: Icons.bluetooth,
                      title: 'Turn on Bluetooth',
                      subtitle: 'Make sure Bluetooth is enabled in your phone settings.',
                    ),
                    const SizedBox(height: 12),
                    const _StepCard(
                      step: 2,
                      icon: Icons.wifi_tethering,
                      title: 'Move closer to the device',
                      subtitle: 'Stay within 10 feet (3 meters) of your ESBUDEN device.',
                    ),
                    const SizedBox(height: 12),
                    const _StepCard(
                      step: 3,
                      icon: Icons.power_settings_new,
                      title: 'Check if ESBUDEN is powered on',
                      subtitle: 'Verify the power indicator light is on and battery is charged.',
                    ),
                    const SizedBox(height: 12),
                    const _StepCard(
                      step: 4,
                      icon: Icons.refresh,
                      title: 'Reset the device',
                      subtitle: 'Press and hold the reset button for 5 seconds to restart.',
                    ),
                    const SizedBox(height: 12),
                    _StepCard(
                      step: 5,
                      icon: Icons.settings,
                      title: 'Try pairing manually',
                      subtitle: 'Go to phone Bluetooth settings and pair with ESBUDEN device.',
                      onTap: () => AppSettings.openAppSettings(
                        type: AppSettingsType.bluetooth,
                      ),
                    ),

                    const SizedBox(height: 18),

                    _InfoCard(
                      primary: primary,
                      title: 'Still having issues?',
                      body:
                          'If the problem persists after trying these steps, your device may need service.',
                      actionText: 'Contact Support →',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact Support (wire later)')),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      primary: primary,
                      title: 'Need visual help?',
                      body: 'Watch our pairing tutorial video',
                      actionText: 'Watch →',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Open tutorial (wire later)')),
                        );
                      },
                    ),

                    const SizedBox(height: 22),
                  ],
                ),
              ),

              // Bottom button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        // ✅ return true so Connect page can auto-rescan
                        Navigator.pop(context, true);
                      },
                      child: const Text(
                        'Try Connecting Again',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$step',
                  style: TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.primary,
    required this.title,
    required this.body,
    required this.actionText,
    required this.onTap,
  });

  final Color primary;
  final String title;
  final String body;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }
}
