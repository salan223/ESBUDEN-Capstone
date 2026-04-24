import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/test_result.dart';
import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _formatDate(dynamic ts) {
    try {
      if (ts == null) return '—';

      DateTime dt;
      if (ts is DateTime) {
        dt = ts;
      } else {
        dt = (ts as dynamic).toDate() as DateTime;
      }

      return DateFormat('MMMM d, yyyy').format(dt);
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
    if (up.contains('MEDIUM')) return 'Medium';
    if (up.contains('LOW')) return 'Low';

    return r;
  }

  Color _riskChipBg(BuildContext context, String label) {
    final l = label.toLowerCase();

    if (l == 'normal' || l == 'stable' || l == 'low') {
      return Colors.green.withOpacity(0.15);
    }
    if (l == 'warning' || l == 'medium') {
      return Colors.orange.withOpacity(0.15);
    }
    if (l == 'high') {
      return Colors.red.withOpacity(0.15);
    }

    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _riskChipFg(String label) {
    final l = label.toLowerCase();

    if (l == 'normal' || l == 'stable' || l == 'low') {
      return Colors.green;
    }
    if (l == 'warning' || l == 'medium') {
      return Colors.orange;
    }
    if (l == 'high') {
      return Colors.red;
    }

    return Colors.black87;
  }

  String _bulletFromTest(TestResult? test) {
    if (test == null) return 'No results yet — run your first test';

    final calcium = test.biomarkers['calcium'];
    final oxalate = test.biomarkers['oxalate'];
    final ph = test.biomarkers['ph'];
    final uricAcid = test.biomarkers['uricAcid'];

    final parts = <String>[];

    if (oxalate != null) parts.add('Oxalate: $oxalate');
    if (calcium != null) parts.add('Calcium: $calcium');
    if (ph != null) parts.add('pH: $ph');
    if (uricAcid != null) parts.add('Uric Acid: $uricAcid');

    return parts.isEmpty ? 'All biomarkers within range' : parts.join(' • ');
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  double? _bioVal(TestResult test, String key) {
    final value = test.biomarkers[key];

    if (value is num) return value.toDouble();

    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed;
  }

  double _averageValueForDashboard(TestResult test) {
    final calcium = _bioVal(test, 'calcium');
    if (calcium != null) return calcium;

    final oxalate = _bioVal(test, 'oxalate');
    if (oxalate != null) return oxalate;

    if (test.intensity.isFinite) return test.intensity;

    return 0.0;
  }

  String _statusFromRecentTests(List<TestResult> recent) {
    if (recent.isEmpty) return 'No Data';

    int rank(String r) {
      final up = r.toUpperCase();

      if (up.contains('HIGH')) return 4;
      if (up.contains('MEDIUM')) return 3;
      if (up.contains('WARN')) return 3;
      if (up.contains('LOW')) return 2;
      if (up.contains('NORMAL')) return 1;

      return 0;
    }

    var worst = 0;

    for (final test in recent) {
      final current = rank(test.overallRisk);
      if (current > worst) worst = current;
    }

    if (worst >= 4) return 'Unstable';
    if (worst == 3) return 'Watch';
    if (worst == 2) return 'Low';
    return 'Stable';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Stable':
        return Colors.green;
      case 'Watch':
        return Colors.orange;
      case 'Unstable':
        return Colors.red;
      case 'Low':
        return Colors.green;
      default:
        return Colors.black54;
    }
  }

  List<TestResult> _lastSevenDaysTests(List<TestResult> all) {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final start = today.subtract(const Duration(days: 6));

    final filtered = all.where((test) {
      final day = _startOfDay(test.createdAt);
      return !day.isBefore(start) && !day.isAfter(today);
    }).toList();

    filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return filtered;
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
          child: ListView(
            children: [
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
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your kidney health',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
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
                            style:
                                Theme.of(context).textTheme.titleLarge?.copyWith(
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
              StreamBuilder<List<TestResult>>(
                stream: tests.watchTests(limit: 200),
                builder: (context, snap) {
                  final all = snap.data ?? [];
                  final recent = _lastSevenDaysTests(all);

                  final values = recent.map(_averageValueForDashboard).toList();

                  final avg = values.isEmpty
                      ? 0.0
                      : values.reduce((a, b) => a + b) / values.length;

                  final status = _statusFromRecentTests(recent);

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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Last 7 days',
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 190,
                            child: _DashboardTrendChart(tests: recent),
                          ),
                          const SizedBox(height: 12),
                          const Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            children: [
                              _LegendDot(
                                label: 'Oxalate',
                                color: Colors.orange,
                              ),
                              _LegendDot(
                                label: 'Calcium',
                                color: Colors.blue,
                              ),
                              _LegendDot(
                                label: 'Uric Acid',
                                color: Colors.green,
                              ),
                            ],
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
                                      avg.toStringAsFixed(1),
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
                                            fontWeight: FontWeight.w900,
                                            color: _statusColor(status),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _NavTile(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () {
                        Navigator.pushNamed(context, Routes.historyReports);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _NavTile(
                      icon: Icons.description_outlined,
                      label: 'Reports',
                      onTap: () {
                        Navigator.pushNamed(context, Routes.reports);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTrendChart extends StatelessWidget {
  const _DashboardTrendChart({required this.tests});

  final List<TestResult> tests;

  double? _bioVal(TestResult test, String key) {
    final value = test.biomarkers[key];

    if (value is num) return value.toDouble();

    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    if (tests.length < 2) {
      return Center(
        child: Text(
          'Not enough data yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),
      );
    }

    LineChartBarData? series(String key, Color color) {
      final spots = <FlSpot>[];

      for (int i = 0; i < tests.length; i++) {
        final value = _bioVal(tests[i], key);
        if (value == null) continue;

        spots.add(FlSpot(i.toDouble(), value));
      }

      if (spots.length < 2) return null;

      return LineChartBarData(
        isCurved: true,
        barWidth: 3,
        color: color,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
        spots: spots,
      );
    }

    final lines = <LineChartBarData>[
      if (series('oxalate', Colors.orange) != null)
        series('oxalate', Colors.orange)!,
      if (series('calcium', Colors.blue) != null)
        series('calcium', Colors.blue)!,
      if (series('uricAcid', Colors.green) != null)
        series('uricAcid', Colors.green)!,
    ];

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'No chart data available yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),
      );
    }

    String bottomLabel(int index) {
      if (index < 0 || index >= tests.length) return '';
      return DateFormat('MMM d').format(tests[index].createdAt);
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: lines,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (tests.length / 3).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.round();

                if (index < 0 || index >= tests.length) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    bottomLabel(index),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 130,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 34),
              const SizedBox(height: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}