import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/test_service.dart';
import '../../models/test_result.dart';
import '../../routes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatDate(dynamic ts) {
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  String _riskLabel(TestResult? test) {
    final r = (test?.overallRisk ?? '').toString().trim();
    if (r.isEmpty) return '—';
    final up = r.toUpperCase();
    if (up.contains('NORMAL')) return 'Normal';
    if (up.contains('HIGH')) return 'High';
    if (up.contains('WARN')) return 'Warning';
    return r;
  }

  Color _riskChipBg(BuildContext context, String label) {
    final l = label.toLowerCase();
    if (l == 'normal' || l == 'stable') return Colors.green.withOpacity(0.15);
    if (l == 'warning') return Colors.orange.withOpacity(0.15);
    if (l == 'high') return Colors.red.withOpacity(0.15);
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _riskChipFg(String label) {
    final l = label.toLowerCase();
    if (l == 'normal' || l == 'stable') return Colors.green;
    if (l == 'warning') return Colors.orange;
    if (l == 'high') return Colors.red;
    return Colors.black87;
  }

  String _bulletFromTest(TestResult? test) {
    if (test == null) return 'No results yet — run your first test';

    final ox = test.biomarkers['oxalate'];
    final ph = test.biomarkers['ph'];
    final protein = test.biomarkers['protein'];

    final parts = <String>[];
    if (ox != null) parts.add('Oxalate: $ox');
    if (ph != null) parts.add('pH: $ph');
    if (protein != null) parts.add('Protein: $protein');

    return parts.isEmpty ? 'All biomarkers within range' : parts.join(' • ');
  }

  double _scoreFromTest(TestResult t) {
    // If you later add a real score field, replace this logic.
    final risk = t.overallRisk.toUpperCase();
    if (risk.contains('NORMAL')) return 90;
    if (risk.contains('WARNING')) return 70;
    if (risk.contains('HIGH')) return 55;
    return 80;
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final tests = TestService();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await auth.signOut();
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              StreamBuilder<String?>(
                stream: auth.userNameStream(),
                builder: (context, snap) {
                  final name = (snap.data == null || snap.data!.trim().isEmpty)
                      ? 'User'
                      : snap.data!.trim();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, $name 👋',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your kidney health',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Last Result card (uses TestResult stream)
              StreamBuilder<TestResult?>(
                stream: tests.watchLatestTest(),
                builder: (context, snap) {
                  final test = snap.data;
                  final label = _riskLabel(test);
                  final dateStr = _formatDate(test?.createdAt);

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Last Result',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _riskChipBg(context, label),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _riskChipFg(label),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            dateStr,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _bulletFromTest(test),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),
              // Start New Test button
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.connectAuto);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text(
                    'Start New Test',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Trend Overview (use watchTests(limit: 7))
              StreamBuilder<List<TestResult>>(
                stream: tests.watchTests(limit: 7),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  final points = list.reversed
                      .map(_scoreFromTest)
                      .toList(); // old->new

                  final avg = points.isEmpty
                      ? 0.0
                      : points.reduce((a, b) => a + b) / points.length;

                  final status = avg >= 80
                      ? 'Stable'
                      : avg >= 65
                      ? 'Watch'
                      : 'Unstable';

                  return Card(
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
                            'Trend Overview',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Last 7 days',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 90,
                            child: _MiniLineChart(values: points),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Average',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${avg.toStringAsFixed(1)}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      status,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: status == 'Stable'
                                                ? Colors.green
                                                : status == 'Watch'
                                                ? Colors.orange
                                                : Colors.red,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              // Bottom tiles
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Open History (wire route next)'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.description_outlined,
                      label: 'Reports',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Open Reports (wire route next)'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  const _MiniLineChart({required this.values});
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Center(
        child: Text(
          'Not enough data yet',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    return CustomPaint(
      painter: _MiniLineChartPainter(
        values: values,
        lineColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({required this.values, required this.lineColor});
  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final dx = size.width / (values.length - 1);

    Offset pointFor(int i) {
      final x = dx * i;
      final norm = (values[i] - minV) / range; // 0..1
      final y = size.height - (norm * (size.height - 8)) - 4;
      return Offset(x, y);
    }

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintDot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(pointFor(0).dx, pointFor(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointFor(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paintLine);

    for (var i = 0; i < values.length; i++) {
      final p = pointFor(i);
      canvas.drawCircle(p, 5, paintDot);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.lineColor != lineColor;
  }
}
