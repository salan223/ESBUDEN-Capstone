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

  DateTime _toDateTime(dynamic ts) {
    try {
      return (ts as dynamic).toDate() as DateTime;
    } catch (_) {
      return DateTime.now();
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// ✅ Use real numeric value stored in Firestore for trend graph:
  /// Prefer top-level `intensity` from your test docs.
  double _trendValueFromTest(TestResult t) {
    // 1) Try direct field: t.intensity
    try {
      final dyn = t as dynamic;
      final v = dyn.intensity;
      if (v is num) return v.toDouble();
      if (v != null) {
        final parsed = double.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    // 2) Try inside biomarkers map
    final b = t.biomarkers['intensity'];
    if (b is num) return b.toDouble();
    final parsed = double.tryParse(b?.toString() ?? '');
    if (parsed != null) return parsed;

    // 3) Fallback: old risk-based synthetic score
    return _scoreFromRisk(t);
  }

  double _scoreFromRisk(TestResult t) {
    final risk = t.overallRisk.toUpperCase();
    if (risk.contains('NORMAL')) return 90;
    if (risk.contains('WARNING')) return 70;
    if (risk.contains('HIGH')) return 55;
    return 80;
  }

  /// Worst-case dominates:
  /// - any HIGH -> Unstable
  /// - else any WARNING -> Watch
  /// - else -> Stable
  String _statusFromRecentTests(List<TestResult> recent) {
    int rank(String r) {
      final up = r.toUpperCase();
      if (up.contains('HIGH')) return 3;
      if (up.contains('WARN')) return 2;
      if (up.contains('NORMAL')) return 1;
      return 0;
    }

    var worst = 0;
    for (final t in recent) {
      final r = rank(t.overallRisk);
      if (r > worst) worst = r;
    }

    if (worst >= 3) return 'Unstable';
    if (worst == 2) return 'Watch';
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
      default:
        return Colors.black54;
    }
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
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your kidney health',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.black54),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 18),

              // Last Result card
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
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

              // Start New Test
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

              // ✅ Trend Overview: Last 7 DAYS using real Firestore intensity values
              StreamBuilder<List<TestResult>>(
                stream: tests.watchTests(limit: 200),
                builder: (context, snap) {
                  final all = snap.data ?? [];
                  final now = DateTime.now();
                  final today = _startOfDay(now);
                  final start = today.subtract(const Duration(days: 6)); // inclusive 7 days

                  // Only tests within last 7 calendar days
                  final inRange = all.where((t) {
                    final dt = _toDateTime(t.createdAt);
                    final day = _startOfDay(dt);
                    return !day.isBefore(start) && !day.isAfter(today);
                  }).toList();

                  // Group intensity values by day
                  final Map<DateTime, List<double>> byDay = {};
                  for (final t in inRange) {
                    final dt = _toDateTime(t.createdAt);
                    final day = _startOfDay(dt);
                    byDay.putIfAbsent(day, () => []);
                    byDay[day]!.add(_trendValueFromTest(t));
                  }

                  // 7 points (old -> new). If no tests on a day, use NaN to create a "gap".
                  final List<double> points = [];
                  for (int i = 0; i < 7; i++) {
                    final day = start.add(Duration(days: i));
                    final vals = byDay[day];
                    if (vals == null || vals.isEmpty) {
                      points.add(double.nan);
                    } else {
                      final avgDay = vals.reduce((a, b) => a + b) / vals.length;
                      points.add(avgDay);
                    }
                  }

                  // Average over all tests in last 7 days
                  final allVals = inRange.map(_trendValueFromTest).toList();
                  final avg = allVals.isEmpty
                      ? 0.0
                      : allVals.reduce((a, b) => a + b) / allVals.length;

                  // Status from worst overallRisk in last 7 days
                  final status = _statusFromRecentTests(inRange);

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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
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
                                            fontWeight: FontWeight.w800,
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

              const SizedBox(height: 14),

              // Bottom tiles
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.history,
                      label: 'History',
                      onTap: () {
                        Navigator.pushNamed(context, Routes.historyReports);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.description_outlined,
                      label: 'Reports',
                      onTap: () {
                        Navigator.pushNamed(context, Routes.reports);
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _MiniLineChart extends StatefulWidget {
  const _MiniLineChart({required this.values});
  final List<double> values; // length = 7, old->new (last 7 days)

  @override
  State<_MiniLineChart> createState() => _MiniLineChartState();
}

class _MiniLineChartState extends State<_MiniLineChart> {
  int? _selectedIndex;

  static const double _topPad = 6;
  static const double _bottomPadForLabels = 22;

  List<String> _dayLabels(int n) {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: n - 1));
    const map = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return List.generate(n, (i) {
      final d = start.add(Duration(days: i));
      return map[d.weekday] ?? '';
    });
  }

  int? _nearestIndex(Offset localPos, Size size) {
    final values = widget.values;
    final valid = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (!values[i].isNaN) valid.add(i);
    }
    if (valid.isEmpty) return null;

    final layout = _MiniChartLayout.compute(
      values: values,
      size: size,
      topPad: _topPad,
      bottomPad: _bottomPadForLabels,
    );

    int best = valid.first;
    double bestDist = (layout.pointFor(best).dx - localPos.dx).abs();

    for (final i in valid) {
      final d = (layout.pointFor(i).dx - localPos.dx).abs();
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }

    return best;
  }

  @override
  Widget build(BuildContext context) {
    final validCount = widget.values.where((v) => !v.isNaN).length;
    if (validCount < 2) {
      return Center(
        child: Text(
          'Not enough data yet',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.black54),
        ),
      );
    }

    final labels = _dayLabels(widget.values.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        final layout = _MiniChartLayout.compute(
          values: widget.values,
          size: size,
          topPad: _topPad,
          bottomPad: _bottomPadForLabels,
        );

        final selected = _selectedIndex;
        final showTooltip = selected != null &&
            selected >= 0 &&
            selected < widget.values.length &&
            !widget.values[selected].isNaN;

        final tooltipPoint = showTooltip ? layout.pointFor(selected!) : null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final idx = _nearestIndex(d.localPosition, size);
            if (idx == null) return;
            setState(() => _selectedIndex = idx);
          },
          onPanStart: (d) {
            final idx = _nearestIndex(d.localPosition, size);
            if (idx == null) return;
            setState(() => _selectedIndex = idx);
          },
          onPanUpdate: (d) {
            final idx = _nearestIndex(d.localPosition, size);
            if (idx == null) return;
            if (idx != _selectedIndex) {
              setState(() => _selectedIndex = idx);
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: size,
                painter: _MiniLineChartPainter(
                  values: widget.values,
                  labels: labels,
                  lineColor: Theme.of(context).colorScheme.primary,
                  topPad: _topPad,
                  bottomPad: _bottomPadForLabels,
                  selectedIndex: _selectedIndex,
                ),
              ),
              if (showTooltip && tooltipPoint != null)
                Positioned(
                  left:
                      (tooltipPoint.dx - 52).clamp(0.0, size.width - 104),
                  top: (tooltipPoint.dy - 44).clamp(0.0, size.height - 60),
                  child: _TooltipBubble(
                    day: labels[selected!],
                    value: widget.values[selected].toStringAsFixed(1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({required this.day, required this.value});
  final String day;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(day,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _MiniChartLayout {
  _MiniChartLayout({
    required this.values,
    required this.size,
    required this.dx,
    required this.lo,
    required this.range,
    required this.topPad,
    required this.bottomPad,
  });

  final List<double> values;
  final Size size;
  final double dx;
  final double lo;
  final double range;
  final double topPad;
  final double bottomPad;

  static _MiniChartLayout compute({
    required List<double> values,
    required Size size,
    required double topPad,
    required double bottomPad,
  }) {
    final valid = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (!values[i].isNaN) valid.add(i);
    }

    double minV = values[valid.first];
    double maxV = values[valid.first];
    for (final i in valid) {
      if (values[i] < minV) minV = values[i];
      if (values[i] > maxV) maxV = values[i];
    }

    final baseRange = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final pad = baseRange * 0.20;
    final lo = minV - pad;
    final hi = maxV + pad;
    final range = (hi - lo).abs() < 0.0001 ? 1.0 : (hi - lo);

    final dx = size.width / (values.length - 1);

    return _MiniChartLayout(
      values: values,
      size: size,
      dx: dx,
      lo: lo,
      range: range,
      topPad: topPad,
      bottomPad: bottomPad,
    );
  }

  Offset pointFor(int i) {
    final x = dx * i;
    final usableH = size.height - topPad - bottomPad;
    final norm = (values[i] - lo) / range;
    final y = topPad + (1 - norm) * usableH;
    return Offset(x, y);
  }
}

class _MiniLineChartPainter extends CustomPainter {
  _MiniLineChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.topPad,
    required this.bottomPad,
    required this.selectedIndex,
  });

  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final double topPad;
  final double bottomPad;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final valid = <int>[];
    for (int i = 0; i < values.length; i++) {
      if (!values[i].isNaN) valid.add(i);
    }
    if (valid.length < 2) return;

    final layout = _MiniChartLayout.compute(
      values: values,
      size: size,
      topPad: topPad,
      bottomPad: bottomPad,
    );

    // vertical separators
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 0; i < values.length; i++) {
      final x = layout.dx * i;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, size.height - bottomPad),
        gridPaint,
      );
    }

    // line + fill
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final pFirst = layout.pointFor(valid.first);
    final linePath = Path()..moveTo(pFirst.dx, pFirst.dy);

    for (int k = 1; k < valid.length; k++) {
      final prev = layout.pointFor(valid[k - 1]);
      final curr = layout.pointFor(valid[k]);
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);

      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);

      if (k == valid.length - 1) {
        linePath.quadraticBezierTo(mid.dx, mid.dy, curr.dx, curr.dy);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(layout.pointFor(valid.last).dx, size.height - bottomPad)
      ..lineTo(layout.pointFor(valid.first).dx, size.height - bottomPad)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    // dots
    final dotPaint = Paint()..color = lineColor;
    for (final i in valid) {
      final p = layout.pointFor(i);
      canvas.drawCircle(p, 5.0, dotPaint);
      canvas.drawCircle(p, 2.2, Paint()..color = Colors.white);
    }

    // selected highlight
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < values.length &&
        !values[selectedIndex!].isNaN) {
      final p = layout.pointFor(selectedIndex!);
      canvas.drawCircle(p, 9, Paint()..color = lineColor.withOpacity(0.18));
      canvas.drawCircle(p, 5.0, dotPaint);
      canvas.drawCircle(p, 2.2, Paint()..color = Colors.white);
    }

    // weekday labels
    final textStyle = TextStyle(
      color: Colors.black.withOpacity(0.45),
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    for (int i = 0; i < labels.length; i++) {
      final x = layout.dx * i;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(x - tp.width / 2, size.height - bottomPad + 6),
      );
    }

    // baseline
    canvas.drawLine(
      Offset(0, size.height - bottomPad),
      Offset(size.width, size.height - bottomPad),
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.labels != labels ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.topPad != topPad ||
        oldDelegate.bottomPad != bottomPad;
  }
}