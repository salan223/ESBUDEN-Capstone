import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/test_result.dart';
import '../../services/auth_service.dart';
import '../../services/test_service.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final tests = TestService();

    return StreamBuilder<String?>(
      stream: auth.userNameStream(),
      builder: (context, nameSnap) {
        final name = (nameSnap.data == null || nameSnap.data!.trim().isEmpty)
            ? 'User'
            : nameSnap.data!.trim();

        final user = auth.currentUser;
        final email = user?.email ?? '—';

        return StreamBuilder<List<TestResult>>(
          stream: tests.watchTests(limit: 200),
          builder: (context, snap) {
            final all = snap.data ?? [];

            // Newest first
            all.sort((a, b) {
              final da = _dtFrom(a.createdAt);
              final db = _dtFrom(b.createdAt);
              return db.compareTo(da);
            });

            return Scaffold(
              appBar: AppBar(
                leading: BackButton(onPressed: () => Navigator.pop(context)),
                title: const Text('Back'),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Reports',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'View and export your medical test reports',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),

                      if (snap.connectionState == ConnectionState.waiting &&
                          all.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (all.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            'No reports yet. Run a test to generate your first report.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: Colors.black54),
                          ),
                        )
                      else
                        ...all.map((t) {
                          final dt = _dtFrom(t.createdAt);
                          final dateText =
                              DateFormat('MMM d, yyyy • h:mm a').format(dt);

                          final riskUp =
                              (t.overallRisk ?? '').toString().toUpperCase();
                          final riskLabel = _riskLabel(riskUp);
                          final riskColor = _riskColor(riskLabel);

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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
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
                                        color: riskColor.withOpacity(0.12),
                                        border: Border.all(
                                            color: riskColor.withOpacity(0.35)),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        riskLabel,
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _ReportDetailScreen(
                                        test: t,
                                        name: name,
                                        email: email,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/* --------------------------- Report Detail Screen --------------------------- */

class _ReportDetailScreen extends StatelessWidget {
  const _ReportDetailScreen({
    required this.test,
    required this.name,
    required this.email,
  });

  final TestResult test;
  final String name;
  final String email;

  Future<void> _showLoading(BuildContext context, String msg) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  void _hideLoading(BuildContext context) {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dt = _dtFrom(test.createdAt);
    final reportDate = _formatReportDate(dt);

    // biomarker values
    final calcium = _num(test.biomarkers['calcium']);
    final oxalate = _num(test.biomarkers['oxalate']);
    final ph = _num(test.biomarkers['ph']);
    final uric = _num(test.biomarkers['uricAcid']);

    // statuses
    final oxStatus = _statusForOxalate(oxalate);
    final caStatus = _statusForCalcium(calcium);
    final phStatus = _statusForPH(ph);
    final uaStatus = _statusForUric(uric);

    // extras (from Firestore doc)
    final imageUrl = _dynString(test, 'imageUrl');
    final rawResult = _dynString(test, 'rawResult');
    final intensity = _dynNum(test, 'intensity');

    final risk = (test.overallRisk ?? '—').toString().toUpperCase();
    final riskLabel = _riskLabel(risk);
    final riskColor = _riskColor(riskLabel);

    // stable reportId: use the test timestamp
    final reportId = _makeReportId('ES', dt);

    Future<Uint8List> makePdf() async {
      return _buildPdfClean(
        name: name,
        email: email,
        reportDate: reportDate,
        reportId: reportId,
        riskLabel: riskLabel,
        calcium: calcium,
        oxalate: oxalate,
        ph: ph,
        uric: uric,
        caStatus: caStatus,
        oxStatus: oxStatus,
        phStatus: phStatus,
        uaStatus: uaStatus,
        imageUrl: imageUrl,
        rawResult: rawResult,
        intensity: intensity,
        doctorNotes: _doctorNotes(
          oxStatus: oxStatus,
          riskLabel: riskLabel,
          rawResult: rawResult,
          intensity: intensity,
        ),
      );
    }

    Future<void> openPreview() async {
      await _showLoading(context, 'Preparing PDF preview...');
      try {
        final bytes = await makePdf();
        if (!context.mounted) return;
        _hideLoading(context);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PdfPreviewScreen(
              buildBytes: () async => bytes,
              filename: _fileNameFromDate(dt),
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        _hideLoading(context);
        _snack(context, 'Failed to generate PDF: $e');
      }
    }

    Future<void> exportPdf() async {
      await _showLoading(context, 'Generating PDF...');
      try {
        final bytes = await makePdf();
        if (!context.mounted) return;
        _hideLoading(context);

        // Always open preview so user sees something even on emulator
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _PdfPreviewScreen(
              buildBytes: () async => bytes,
              filename: _fileNameFromDate(dt),
            ),
          ),
        );

        try {
          await Printing.sharePdf(bytes: bytes, filename: _fileNameFromDate(dt));
        } catch (_) {
          _snack(
            context,
            'Sharing may not be available on this emulator. Use share/print inside PDF Preview or test on a real phone.',
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        _hideLoading(context);
        _snack(context, 'Failed to export PDF: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const Text('Back'),
        actions: [
          TextButton(
            onPressed: openPreview,
            child: const Text('PDF Preview'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: _ReportCard(
                  name: name,
                  email: email,
                  reportDate: reportDate,
                  reportId: reportId,
                  riskLabel: riskLabel,
                  riskColor: riskColor,
                  calcium: calcium,
                  oxalate: oxalate,
                  ph: ph,
                  uric: uric,
                  caStatus: caStatus,
                  oxStatus: oxStatus,
                  phStatus: phStatus,
                  uaStatus: uaStatus,
                  doctorNotes: _doctorNotes(
                    oxStatus: oxStatus,
                    riskLabel: riskLabel,
                    rawResult: rawResult,
                    intensity: intensity,
                  ),
                  imageUrl: imageUrl,
                  rawResult: rawResult,
                  intensity: intensity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: exportPdf,
                  icon: const Icon(Icons.download),
                  label: const Text(
                    'Export as PDF',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------- UI (Medical Report Card) --------------------------- */

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.name,
    required this.email,
    required this.reportDate,
    required this.reportId,
    required this.riskLabel,
    required this.riskColor,
    required this.calcium,
    required this.oxalate,
    required this.ph,
    required this.uric,
    required this.caStatus,
    required this.oxStatus,
    required this.phStatus,
    required this.uaStatus,
    required this.doctorNotes,
    required this.imageUrl,
    required this.rawResult,
    required this.intensity,
  });

  final String name;
  final String email;
  final String reportDate;
  final String reportId;

  final String riskLabel;
  final Color riskColor;

  final double? calcium;
  final double? oxalate;
  final double? ph;
  final double? uric;

  final String caStatus;
  final String oxStatus;
  final String phStatus;
  final String uaStatus;

  final String doctorNotes;
  final String? imageUrl;
  final String? rawResult;
  final double? intensity;

  void _openSuggestions(
    BuildContext context, {
    required String biomarkerName,
    required String status,
  }) {
    final tips = _suggestionsFor(biomarkerName, status);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$biomarkerName • $status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  'General suggestions (not medical advice):',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ...tips.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                        Expanded(
                          child: Text(
                            t,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'If you have symptoms or concerns, please talk to a qualified healthcare professional.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ES',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('URI-TRACK',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('Medical Test Report',
                          style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Report Date',
                        style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(reportDate,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            _SectionTitle('Patient Information'),
            const SizedBox(height: 10),

            // Only Name + Email
            Row(
              children: [
                Expanded(child: _InfoCell(label: 'Patient Name', value: name)),
                const SizedBox(width: 12),
                Expanded(child: _InfoCell(label: 'Email', value: email)),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            _SectionTitle('Test Summary'),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Overall Risk Level:',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: riskColor.withOpacity(0.35)),
                        ),
                        child: Text(
                          riskLabel,
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: riskColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Raw Result: ${rawResult ?? '—'}',
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Intensity: ${intensity == null ? '—' : intensity!.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            _SectionTitle('Biomarker Values'),
            const SizedBox(height: 10),

            _BiomarkerTable(
              calcium: calcium,
              oxalate: oxalate,
              ph: ph,
              uric: uric,
              caStatus: caStatus,
              oxStatus: oxStatus,
              phStatus: phStatus,
              uaStatus: uaStatus,
              onInfoTap: (biomarker, status){
                _openSuggestions(
                  context,
                  biomarkerName: biomarker,
                  status: status,
                );
              },
            ),

            const SizedBox(height: 18),
            _SectionTitle('Color Response Image'),
            const SizedBox(height: 10),

            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  color: Colors.grey.shade100,
                ),
                child: (imageUrl == null || imageUrl!.trim().isEmpty)
                    ? const Center(
                        child: Text(
                          'No image available',
                          style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Failed to load image',
                            style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 18),
            _SectionTitle("Doctor's Notes / Interpretation"),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withOpacity(0.18)),
              ),
              child: Text(
                doctorNotes,
                style: const TextStyle(height: 1.35),
              ),
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Important Note:',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text(
                    'This report is generated by URI-TRACK automated urinalysis system. '
                    'Results should be reviewed by a qualified healthcare professional. '
                    'This is not a substitute for professional medical advice, diagnosis, or treatment.',
                    style: TextStyle(color: Colors.black54, height: 1.35),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Text(
              'Report ID: $reportId',
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Generated by URI-TRACK Medical Systems v2.1.0',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

typedef SuggestionsCallback = void Function(String biomarkerName, String status);

class _BiomarkerTable extends StatelessWidget {
  const _BiomarkerTable({
    required this.calcium,
    required this.oxalate,
    required this.ph,
    required this.uric,
    required this.caStatus,
    required this.oxStatus,
    required this.phStatus,
    required this.uaStatus,
    this.onInfoTap, // optional callback
  });

  final double? calcium;
  final double? oxalate;
  final double? ph;
  final double? uric;

  final String caStatus;
  final String oxStatus;
  final String phStatus;
  final String uaStatus;

  // Optional: let parent show bottom-sheet tips when user taps info
  final void Function(String biomarker, String status)? onInfoTap;

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up.contains('ELEV')) return Colors.orange;
    if (up.contains('HIGH')) return Colors.red;
    if (up.contains('LOW')) return Colors.orange;
    if (up.contains('NORMAL')) return Colors.green;
    return Colors.black54;
  }

  bool _needsInfo(String status) {
    final up = status.toUpperCase();
    return up.contains('HIGH') || up.contains('LOW') || up.contains('ELEV');
  }

  @override
  Widget build(BuildContext context) {
    Widget headerCell(String text, {TextAlign align = TextAlign.left}) {
      return Text(
        text,
        textAlign: align,
        style: const TextStyle(color: Colors.black54),
        overflow: TextOverflow.ellipsis,
      );
    }

    Widget bodyCell(String text,
        {TextAlign align = TextAlign.left, FontWeight weight = FontWeight.w400}) {
      return Text(
        text,
        textAlign: align,
        style: TextStyle(fontWeight: weight),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      );
    }

    Widget statusCell(String status) {
      return Text(
        status,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: _statusColor(status),
        ),
      );
    }

    Widget infoButton(String biomarker, String status) {
      if (!_needsInfo(status)) return const SizedBox(width: 32, height: 32);

      return SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.info_outline, size: 20),
          onPressed: () {
            if (onInfoTap != null) {
              onInfoTap!(biomarker, status);
            } else {
              // safe fallback if you haven't wired tips yet
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tips for $biomarker ($status) – wire later')),
              );
            }
          },
        ),
      );
    }

    Widget row({
      required String biomarker,
      required String value,
      required String range,
      required String status,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Biomarker
            Expanded(
              flex: 24,
              child: bodyCell(biomarker, weight: FontWeight.w700),
            ),

            // Value
            Expanded(
              flex: 26,
              child: bodyCell(value),
            ),

            // Normal Range
            Expanded(
              flex: 24,
              child: bodyCell(range),
            ),

            // Status (slightly smaller flex)
            Expanded(
              flex: 18,
              child: statusCell(status),
            ),

            // Fixed-width info icon column (prevents overflow)
            const SizedBox(width: 6),
            infoButton(biomarker, status),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: const [
              Expanded(flex: 24, child: Text('Biomarker', style: TextStyle(color: Colors.black54))),
              Expanded(flex: 26, child: Text('Value', style: TextStyle(color: Colors.black54))),
              Expanded(flex: 24, child: Text('Normal Range', style: TextStyle(color: Colors.black54))),
              Expanded(flex: 18, child: Text('Status', style: TextStyle(color: Colors.black54))),
              SizedBox(width: 6),
              SizedBox(width: 32), // aligns header with info column
            ],
          ),
          const Divider(height: 18),

          row(
            biomarker: 'Calcium',
            value: _fmt(calcium, 2, suffix: ' mmol/L'),
            range: '2.2 - 2.6',
            status: caStatus,
          ),
          row(
            biomarker: 'Oxalate',
            value: _fmt(oxalate, 2, suffix: ' mmol/L'),
            range: '0.0 - 0.40',
            status: oxStatus,
          ),
          row(
            biomarker: 'pH Level',
            value: _fmt(ph, 1),
            range: '5.5 - 7.0',
            status: phStatus,
          ),
          row(
            biomarker: 'Uric Acid',
            value: _fmt(uric, 2, suffix: ' mmol/L'),
            range: '0.15 - 0.45',
            status: uaStatus,
          ),
        ],
      ),
    );
  }
}

/* ------------------------------ PDF Preview ------------------------------ */

class _PdfPreviewScreen extends StatelessWidget {
  const _PdfPreviewScreen({
    required this.buildBytes,
    required this.filename,
  });

  final Future<Uint8List> Function() buildBytes;
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF Preview')),
      body: PdfPreview(
        build: (format) => buildBytes(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: filename,
        useActions: true,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}

/* --------------------------- CLEAN PDF GENERATION --------------------------- */

Future<Uint8List> _buildPdfClean({
  required String name,
  required String email,
  required String reportDate,
  required String reportId,
  required String riskLabel,
  required double? calcium,
  required double? oxalate,
  required double? ph,
  required double? uric,
  required String caStatus,
  required String oxStatus,
  required String phStatus,
  required String uaStatus,
  required String? imageUrl, // kept as placeholder (fast)
  required String? rawResult,
  required double? intensity,
  required String doctorNotes,
}) async {
  final doc = pw.Document();

  final PdfColor riskColor = () {
    final up = riskLabel.toUpperCase();
    if (up.contains('HIGH')) return PdfColors.red700;
    if (up.contains('WARN')) return PdfColors.orange700;
    if (up.contains('NORMAL')) return PdfColors.green700;
    return PdfColors.grey700;
  }();

  final title = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  final h = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
  final small = const pw.TextStyle(fontSize: 10);
  final muted = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);

  // Monospace for numbers (prevents overlap / weird glyph blocks)
  final mono = pw.TextStyle(fontSize: 10, font: pw.Font.courier());

  pw.Widget section(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Text(t, style: h),
      );

  pw.Table biomarkerTable() {
    final th = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey700,
    );

    pw.TextStyle statusStyle(String s) {
      final up = s.toUpperCase();
      if (up.contains('HIGH') || up.contains('ELEV')) {
        return pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.red700);
      }
      if (up.contains('LOW') || up.contains('WARN')) {
        return pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.orange700);
      }
      if (up.contains('NORMAL')) {
        return pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green700);
      }
      return pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700);
    }

    pw.TableRow row(String b, String v, String r, String s) => pw.TableRow(
          children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(b, style: small)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(v, style: mono)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(r, style: mono)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(s, style: statusStyle(s))),
          ],
        );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(2.0),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Biomarker', style: th)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Value', style: th)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Normal Range', style: th)),
            pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Status', style: th)),
          ],
        ),
        row('Calcium', _fmt(calcium, 2, suffix: ' mmol/L'), '2.2 - 2.6',
            caStatus),
        row('Oxalate', _fmt(oxalate, 2, suffix: ' mmol/L'), '0.0 - 0.40',
            oxStatus),
        row('pH Level', _fmt(ph, 1), '5.5 - 7.0', phStatus),
        row('Uric Acid', _fmt(uric, 2, suffix: ' mmol/L'), '0.15 - 0.45',
            uaStatus),
      ],
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => [
        // Header
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 34,
              height: 34,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColors.blue700,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'ES',
                style: pw.TextStyle(
                    color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('URI-TRACK', style: title),
                pw.Text('Medical Test Report', style: muted),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Report Date', style: muted),
                pw.Text(
                  reportDate,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),

        // Patient info
        section('Patient Information'),
        pw.Text('Patient Name: $name', style: small),
        pw.SizedBox(height: 4),
        pw.Text('Email: $email', style: small),

        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300),

        // Summary
        section('Test Summary'),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Text(
                'Overall Risk Level:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(width: 8),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: riskColor),
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  riskLabel,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: riskColor),
                ),
              ),
              pw.Spacer(),
              pw.Text('Raw Result: ', style: muted),
              pw.Text(
                (rawResult == null || rawResult.trim().isEmpty)
                    ? '—'
                    : rawResult.trim(),
                style: small,
              ),
              pw.SizedBox(width: 12),
              pw.Text('Intensity: ', style: muted),
              pw.Text(intensity == null ? '—' : intensity.toStringAsFixed(2),
                  style: mono),
            ],
          ),
        ),

        section('Biomarker Values'),
        biomarkerTable(),

        // Image placeholder (fast)
        section('Color Response Image'),
        pw.Container(
          height: 140,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            (imageUrl == null || imageUrl.trim().isEmpty)
                ? 'No image available'
                : 'Image available in app (not embedded in PDF for performance)',
            style: muted,
            textAlign: pw.TextAlign.center,
          ),
        ),

        section("Doctor's Notes / Interpretation"),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue200),
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            doctorNotes,
            style: pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ),

        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Text(
            'Important Note: This report is generated by URI-TRACK automated urinalysis system. '
            'Results should be reviewed by a qualified healthcare professional. '
            'This is not a substitute for professional medical advice, diagnosis, or treatment.',
            style: muted,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Report ID: $reportId', style: muted),
        pw.Text('Generated by URI-TRACK Medical Systems v2.1.0', style: muted),
      ],
    ),
  );

  return doc.save();
}

/* ------------------------------ Suggestions ------------------------------ */

List<String> _suggestionsFor(String biomarkerName, String status) {
  final upStatus = status.toUpperCase();
  final name = biomarkerName.toLowerCase();

  // These are general wellness tips (NOT diagnosis/treatment).
  // You can refine later with your stakeholders / clinician partner.
  if (name.contains('calcium')) {
    if (upStatus.contains('HIGH')) {
      return [
        'Drink enough water throughout the day (aim for pale yellow urine).',
        'Avoid overusing calcium supplements unless prescribed.',
        'Balance sodium (salty foods can increase calcium in urine for some people).',
        'If this keeps happening, ask a healthcare professional about testing and diet guidance.',
      ];
    }
    if (upStatus.contains('LOW')) {
      return [
        'Make sure your diet includes calcium-containing foods (if appropriate for you).',
        'Avoid skipping meals and try to keep nutrition balanced.',
        'If you are restricting foods, ask a healthcare professional for safe guidance.',
      ];
    }
  }

  if (name.contains('oxalate')) {
    if (upStatus.contains('ELEV') || upStatus.contains('HIGH')) {
      return [
        'Stay hydrated—water helps dilute urine.',
        'If you eat lots of high-oxalate foods, consider moderating them (ask a professional for a safe plan).',
        'Pairing oxalate foods with calcium-containing foods can help some people (confirm with a clinician).',
      ];
    }
  }

  if (name.contains('uric')) {
    if (upStatus.contains('HIGH')) {
      return [
        'Hydration is important; spread water intake through the day.',
        'Moderate sugary drinks; choose water more often.',
        'If you have frequent high readings, ask a healthcare professional about diet patterns and follow-up testing.',
      ];
    }
  }

  if (name.contains('ph')) {
    if (upStatus.contains('LOW') || upStatus.contains('HIGH')) {
      return [
        'Hydration and balanced meals can help keep urine chemistry steadier.',
        'If you have repeated abnormal pH readings, ask a healthcare professional for interpretation.',
      ];
    }
  }

  // Default
  return [
    'Stay hydrated and keep a balanced diet.',
    'Retest later to confirm the trend.',
    'If you have symptoms or concerns, talk to a healthcare professional.',
  ];
}

/* ------------------------------ Helpers ------------------------------ */

DateTime _dtFrom(dynamic ts) {
  try {
    return (ts as dynamic).toDate() as DateTime;
  } catch (_) {
    if (ts is DateTime) return ts;
    return DateTime.now();
  }
}

String _formatReportDate(DateTime dt) =>
    DateFormat("MMMM d, yyyy 'at' h:mm a").format(dt);

String _makeReportId(String prefix, DateTime dt) {
  final compact = DateFormat('yyyyMMddHHmmss').format(dt);
  return '$prefix-$compact';
}

String _fileNameFromDate(DateTime dt) {
  final d = DateFormat('yyyy-MM-dd_HHmm').format(dt);
  return 'URI-TRACK_Report_$d.pdf';
}

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

String _fmt(double? v, int decimals, {String suffix = ''}) {
  if (v == null) return '—';
  return '${v.toStringAsFixed(decimals)}$suffix';
}

String _riskLabel(String risk) {
  final up = risk.toUpperCase();
  if (up.contains('HIGH')) return 'High Risk';
  if (up.contains('WARN')) return 'Warning';
  if (up.contains('NORMAL')) return 'Normal';
  if (risk.trim().isEmpty || risk.trim() == '—') return '—';
  return risk;
}

Color _riskColor(String label) {
  final l = label.toLowerCase();
  if (l.contains('normal')) return Colors.green;
  if (l.contains('warning')) return Colors.orange;
  if (l.contains('high')) return Colors.red;
  return Colors.grey;
}

String _statusForOxalate(double? ox) {
  if (ox == null) return '—';
  if (ox <= 0.40) return 'Normal';
  return 'Elevated';
}

String _statusForCalcium(double? ca) {
  if (ca == null) return '—';
  if (ca < 2.2) return 'Low';
  if (ca > 2.6) return 'High';
  return 'Normal';
}

String _statusForPH(double? ph) {
  if (ph == null) return '—';
  if (ph < 5.5) return 'Low';
  if (ph > 7.0) return 'High';
  return 'Normal';
}

String _statusForUric(double? ua) {
  if (ua == null) return '—';
  if (ua < 0.15) return 'Low';
  if (ua > 0.45) return 'High';
  return 'Normal';
}

String _doctorNotes({
  required String oxStatus,
  required String riskLabel,
  required String? rawResult,
  required double? intensity,
}) {
  final oxUp = oxStatus.toUpperCase();
  final riskUp = riskLabel.toUpperCase();
  final rr =
      (rawResult == null || rawResult.trim().isEmpty) ? null : rawResult.trim();

  if (riskUp.contains('HIGH')) {
    return 'The test results indicate high risk. Consider re-testing soon and consult a healthcare professional for guidance. '
        '${rr != null ? "Strip classification: $rr. " : ""}'
        '${intensity != null ? "Measured intensity: ${intensity.toStringAsFixed(2)}. " : ""}'
        'Maintain adequate hydration and monitor symptoms closely.';
  }

  if (riskUp.contains('WARNING') || oxUp.contains('ELEV')) {
    return 'The test results indicate a warning-level reading. '
        '${rr != null ? "Strip classification: $rr. " : ""}'
        '${intensity != null ? "Measured intensity: ${intensity.toStringAsFixed(2)}. " : ""}'
        'Increase fluid intake and consider reducing high-oxalate foods. Regular monitoring is recommended.';
  }

  return 'All biomarkers appear within expected ranges. '
      '${rr != null ? "Strip classification: $rr. " : ""}'
      '${intensity != null ? "Measured intensity: ${intensity.toStringAsFixed(2)}. " : ""}'
      'Maintain hydration and continue routine monitoring to track trends over time.';
}

// dynamic helpers (safe access to extra fields)
String? _dynString(TestResult t, String field) {
  try {
    final dyn = t as dynamic;
    final map = dyn.toMap();
    final v = map[field];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}
  return null;
}

double? _dynNum(TestResult t, String field) {
  try {
    final dyn = t as dynamic;
    final map = dyn.toMap();
    final v = map[field];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  } catch (_) {}
  return null;
}