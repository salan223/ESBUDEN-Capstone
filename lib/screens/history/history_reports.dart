import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../services/test_service.dart';
import '../../models/test_result.dart';

enum SortMode { newestFirst, oldestFirst, highestRiskFirst }

class HistoryReportsPage extends StatefulWidget {
  const HistoryReportsPage({super.key});

  @override
  State<HistoryReportsPage> createState() => _HistoryReportsPageState();
}

class _HistoryReportsPageState extends State<HistoryReportsPage> {
  final tests = TestService();

  // Top pills
  int _rangeIndex = 0; // 0=All, 1=7 days, 2=30 days

  // Filter sheet state
  DateTime? _from;
  DateTime? _to;
  final Set<String> _statusFilter = {}; // NORMAL/WARNING/HIGH
  final Set<String> _biomarkerFilter = {'oxalate', 'calcium', 'uricAcid'};
  SortMode _sortMode = SortMode.newestFirst;

  // Used by chart + list
  List<TestResult> _applyFilters(List<TestResult> input) {
    final now = DateTime.now();

    DateTime? from = _from;
    DateTime? to = _to;

    // Apply quick-range if user selected 7/30 days
    if (_rangeIndex == 1) {
      from = now.subtract(const Duration(days: 7));
      to = now;
    } else if (_rangeIndex == 2) {
      from = now.subtract(const Duration(days: 30));
      to = now;
    }

    bool inRange(DateTime dt) {
      if (from != null && dt.isBefore(_startOfDay(from))) return false;
      if (to != null && dt.isAfter(_endOfDay(to))) return false;
      return true;
    }

    bool statusOk(String risk) {
      if (_statusFilter.isEmpty) return true;
      return _statusFilter.contains(risk.toUpperCase());
    }

    final filtered = input.where((t) {
      final dt = t.createdAt ?? DateTime.now();
      final risk = (t.overallRisk ?? '').toUpperCase();
      return inRange(dt) && statusOk(risk);
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final da = a.createdAt ?? DateTime.now();
      final db = b.createdAt ?? DateTime.now();

      switch (_sortMode) {
        case SortMode.newestFirst:
          return db.compareTo(da);
        case SortMode.oldestFirst:
          return da.compareTo(db);
        case SortMode.highestRiskFirst:
          int rank(String r) {
            r = r.toUpperCase();
            if (r == 'HIGH') return 3;
            if (r == 'WARNING') return 2;
            if (r == 'NORMAL') return 1;
            return 0;
          }

          final ra = rank(a.overallRisk ?? '');
          final rb = rank(b.overallRisk ?? '');
          final cmp = rb.compareTo(ra);
          if (cmp != 0) return cmp;
          return db.compareTo(da); // tie-breaker: newest first
      }
    });

    return filtered;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 0, 0, 0);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'NORMAL':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'HIGH':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _riskLabel(String risk) {
    final r = risk.toUpperCase();
    if (r == 'HIGH') return 'High Risk';
    if (r == 'WARNING') return 'Warning';
    if (r == 'NORMAL') return 'Normal';
    return risk;
  }

  double? _bioVal(TestResult t, String key) {
    final v = t.biomarkers?[key];
    if (v is num) return v.toDouble();
    return null;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterState>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return _FilterSheet(
          initial: _FilterState(
            from: _from,
            to: _to,
            status: {..._statusFilter},
            biomarkers: {..._biomarkerFilter},
            sortMode: _sortMode,
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _from = result.from;
      _to = result.to;
      _statusFilter
        ..clear()
        ..addAll(result.status);

      _biomarkerFilter
        ..clear()
        ..addAll(result.biomarkers);

      _sortMode = result.sortMode;

      // If user chose a custom date range, set top pills back to All Tests
      if (_from != null || _to != null) {
        _rangeIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TestResult>>(
      stream: tests.watchTests(limit: 200),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final filtered = _applyFilters(all);

        // For chart, sort oldest -> newest (trend direction)
        final chartData = [...filtered]
          ..sort((a, b) =>
              (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => Navigator.pop(context)),
            title: const Text('Back'),
            actions: [
              IconButton(
                tooltip: 'Filter',
                onPressed: _openFilterSheet,
                icon: const Icon(Icons.filter_alt_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: ListView(
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'History & Reports',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track your biomarker trends over time',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black54,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Range pills
                  Row(
                    children: [
                      _Pill(
                        text: 'All Tests',
                        selected: _rangeIndex == 0,
                        onTap: () => setState(() {
                          _rangeIndex = 0;
                          _from = null;
                          _to = null;
                        }),
                      ),
                      const SizedBox(width: 10),
                      _Pill(
                        text: 'Last 7 Days',
                        selected: _rangeIndex == 1,
                        onTap: () => setState(() {
                          _rangeIndex = 1;
                          _from = null;
                          _to = null;
                        }),
                      ),
                      const SizedBox(width: 10),
                      _Pill(
                        text: 'Last 30 Days',
                        selected: _rangeIndex == 2,
                        onTap: () => setState(() {
                          _rangeIndex = 2;
                          _from = null;
                          _to = null;
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Biomarker Trends card
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
                          Row(
                            children: [
                              Icon(Icons.show_chart,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Biomarker Trends',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 260,
                            child: _TrendChart(
                              tests: chartData,
                              biomarkersToShow: _biomarkerFilter,
                              getValue: _bioVal,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            children: [
                              if (_biomarkerFilter.contains('oxalate'))
                                const _LegendDot(label: 'Oxalate', color: Colors.orange),
                              if (_biomarkerFilter.contains('calcium'))
                                const _LegendDot(label: 'Calcium', color: Colors.blue),
                              if (_biomarkerFilter.contains('uricAcid'))
                                const _LegendDot(label: 'Uric Acid', color: Colors.green),
                              if (_biomarkerFilter.contains('ph'))
                                const _LegendDot(label: 'pH', color: Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Past Test Results',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),

                  if (snap.connectionState == ConnectionState.waiting && all.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'No results found with your current filters.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    )
                  else
                    ...filtered.map((t) {
                      final dt = t.createdAt ?? DateTime.now();
                      final dateText = DateFormat('MMM d, yyyy').format(dt);
                      final risk = (t.overallRisk ?? '').toUpperCase();
                      final chipColor = _riskColor(risk);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            title: Text(
                              dateText,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipColor.withOpacity(0.12),
                                    border: Border.all(color: chipColor.withOpacity(0.35)),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _riskLabel(risk),
                                    style: TextStyle(
                                      color: chipColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: open detail page (optional)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Open result details (wire later)')),
                              );
                            },
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 18),

                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () {
                        // TODO: export PDF/CSV later
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export (wire later)')),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'Export All Reports',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? primary : Colors.black12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.tests,
    required this.biomarkersToShow,
    required this.getValue,
  });

  final List<TestResult> tests;
  final Set<String> biomarkersToShow;
  final double? Function(TestResult, String) getValue;

  @override
  Widget build(BuildContext context) {
    if (tests.length < 2) {
      return Center(
        child: Text(
          'Not enough data to show a trend yet.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
      );
    }

    // Build series
    LineChartBarData? series(String key, Color color) {
      if (!biomarkersToShow.contains(key)) return null;

      final spots = <FlSpot>[];
      for (int i = 0; i < tests.length; i++) {
        final v = getValue(tests[i], key);
        if (v == null) continue;
        spots.add(FlSpot(i.toDouble(), v));
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
      if (series('oxalate', Colors.orange) != null) series('oxalate', Colors.orange)!,
      if (series('calcium', Colors.blue) != null) series('calcium', Colors.blue)!,
      if (series('uricAcid', Colors.green) != null) series('uricAcid', Colors.green)!,
      if (series('ph', Colors.purple) != null) series('ph', Colors.purple)!,
    ];

    if (lines.isEmpty) {
      return Center(
        child: Text(
          'No chart data for selected biomarkers.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
      );
    }

    String bottomLabel(int i) {
      final dt = tests[i].createdAt ?? DateTime.now();
      return DateFormat('MMM d').format(dt);
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: lines,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (tests.length / 4).clamp(1, 999).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= tests.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    bottomLabel(i),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
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

class _FilterState {
  _FilterState({
    required this.from,
    required this.to,
    required this.status,
    required this.biomarkers,
    required this.sortMode,
  });

  DateTime? from;
  DateTime? to;
  Set<String> status;
  Set<String> biomarkers;
  SortMode sortMode;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _FilterState initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? from;
  DateTime? to;
  late Set<String> status;
  late Set<String> biomarkers;
  late SortMode sortMode;

  @override
  void initState() {
    super.initState();
    from = widget.initial.from;
    to = widget.initial.to;
    status = {...widget.initial.status};
    biomarkers = {...widget.initial.biomarkers};
    sortMode = widget.initial.sortMode;
  }

  Future<void> pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: from ?? now,
    );
    if (picked != null) setState(() => from = picked);
  }

  Future<void> pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: to ?? now,
    );
    if (picked != null) setState(() => to = picked);
  }

  void _apply() {
    Navigator.pop(
      context,
      _FilterState(
        from: from,
        to: to,
        status: status,
        biomarkers: biomarkers,
        sortMode: sortMode,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      from = null;
      to = null;
      status.clear();
      biomarkers
        ..clear()
        ..addAll({'oxalate', 'calcium', 'uricAcid'});
      sortMode = SortMode.newestFirst;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    // ✅ Makes the bottom sheet scrollable + draggable (no overflow)
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SafeArea(
          top: false,
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  const SizedBox(height: 6),

                  // Header
                  Row(
                    children: [
                      Icon(Icons.filter_alt_outlined, color: primary),
                      const SizedBox(width: 10),
                      Text(
                        'Filter & Sort',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ✅ Scrollable content
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // Date range
                        Text(
                          'Date Range',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        _DateField(label: 'From', value: from, onTap: pickFrom),
                        const SizedBox(height: 12),
                        _DateField(label: 'To', value: to, onTap: pickTo),

                        const SizedBox(height: 18),

                        // Status filter
                        Text(
                          'Status Filter',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ChipToggle(
                              text: 'Normal',
                              selected: status.contains('NORMAL'),
                              onTap: () => setState(() {
                                status.contains('NORMAL')
                                    ? status.remove('NORMAL')
                                    : status.add('NORMAL');
                              }),
                            ),
                            _ChipToggle(
                              text: 'Warning',
                              selected: status.contains('WARNING'),
                              onTap: () => setState(() {
                                status.contains('WARNING')
                                    ? status.remove('WARNING')
                                    : status.add('WARNING');
                              }),
                            ),
                            _ChipToggle(
                              text: 'High Risk',
                              selected: status.contains('HIGH'),
                              onTap: () => setState(() {
                                status.contains('HIGH')
                                    ? status.remove('HIGH')
                                    : status.add('HIGH');
                              }),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Biomarker filter
                        Text(
                          'Biomarker Filter',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ChipToggle(
                              text: 'Calcium',
                              selected: biomarkers.contains('calcium'),
                              onTap: () => setState(() {
                                biomarkers.contains('calcium')
                                    ? biomarkers.remove('calcium')
                                    : biomarkers.add('calcium');
                              }),
                            ),
                            _ChipToggle(
                              text: 'Oxalate',
                              selected: biomarkers.contains('oxalate'),
                              onTap: () => setState(() {
                                biomarkers.contains('oxalate')
                                    ? biomarkers.remove('oxalate')
                                    : biomarkers.add('oxalate');
                              }),
                            ),
                            _ChipToggle(
                              text: 'pH',
                              selected: biomarkers.contains('ph'),
                              onTap: () => setState(() {
                                biomarkers.contains('ph')
                                    ? biomarkers.remove('ph')
                                    : biomarkers.add('ph');
                              }),
                            ),
                            _ChipToggle(
                              text: 'Uric Acid',
                              selected: biomarkers.contains('uricAcid'),
                              onTap: () => setState(() {
                                biomarkers.contains('uricAcid')
                                    ? biomarkers.remove('uricAcid')
                                    : biomarkers.add('uricAcid');
                              }),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // Sort
                        Text(
                          'Sort By',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 10),

                        _SortTile(
                          title: 'Newest First',
                          subtitle: 'Most recent tests first',
                          selected: sortMode == SortMode.newestFirst,
                          onTap: () => setState(() => sortMode = SortMode.newestFirst),
                        ),
                        const SizedBox(height: 10),
                        _SortTile(
                          title: 'Oldest First',
                          subtitle: 'Earlier tests first',
                          selected: sortMode == SortMode.oldestFirst,
                          onTap: () => setState(() => sortMode = SortMode.oldestFirst),
                        ),
                        const SizedBox(height: 10),
                        _SortTile(
                          title: 'Highest Risk First',
                          subtitle: 'Critical results first',
                          selected: sortMode == SortMode.highestRiskFirst,
                          onTap: () => setState(() => sortMode = SortMode.highestRiskFirst),
                        ),

                        const SizedBox(height: 90), // space so last tile isn't behind buttons
                      ],
                    ),
                  ),

                  // ✅ Sticky bottom buttons (no overflow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 10),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _apply,
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _clearAll,
                            child: const Text('Clear All'),
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
      },
    );
  }
}


class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final txt = value == null ? 'yyyy-mm-dd' : DateFormat('yyyy-MM-dd').format(value!);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(txt, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_outlined, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? primary : Colors.black12),
          color: selected ? primary.withOpacity(0.10) : Colors.white,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? primary : Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SortTile extends StatelessWidget {
  const _SortTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? primary : Colors.black12),
          color: selected ? primary.withOpacity(0.08) : Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected ? primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 18, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
