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
        final uid = user?.uid ?? '—';

        return StreamBuilder<TestResult?>(
          stream: tests.watchLatestTest(),
          builder: (context, testSnap) {
            final latest = testSnap.data;

            final dt = _dtFrom(latest?.createdAt);
            final reportDate = _formatReportDate(dt);
            final reportId = _makeReportId(uid, dt);

            final risk = (latest?.overallRisk ?? '—').toString().toUpperCase();
            final riskLabel = _riskLabel(risk);
            final riskColor = _riskColor(riskLabel);

            final calcium = _num(latest?.biomarkers['calcium']);
            final oxalate = _num(latest?.biomarkers['oxalate']);
            final ph = _num(latest?.biomarkers['ph']);
            final uric = _num(latest?.biomarkers['uricAcid']);

            final oxStatus = _statusForOxalate(oxalate);
            final caStatus = _statusForCalcium(calcium);
            final phStatus = _statusForPH(ph);
            final uaStatus = _statusForUric(uric);

            // Firestore extras (your screenshot)
            final imageUrl = _dynString(latest, 'imageUrl');
            final rawResult = _dynString(latest, 'rawResult');
            final intensity = _dynNum(latest, 'intensity');

            Future<Uint8List> makePdf() async {
              return _buildPdfClean(
                name: name,
                email: email,
                uid: uid,
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

                // Always open preview (emulator share can be “silent”)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _PdfPreviewScreen(
                      buildBytes: () async => bytes,
                      filename: _fileNameFromDate(dt),
                    ),
                  ),
                );

                // Try share (may fail on emulator)
                try {
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: _fileNameFromDate(dt),
                  );
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          },
        );
      },
    );
  }
}

/* --------------------------- UI (Report Card) --------------------------- */

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
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('URI-TRACK', style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 2),
                      Text('Medical Test Report', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Report Date', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(reportDate, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            _SectionTitle('Patient Information'),
            const SizedBox(height: 10),

            // ✅ Only show Name + Email (no Patient ID / UID)
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: riskColor.withOpacity(0.35)),
                        ),
                        child: Text(
                          riskLabel,
                          style: TextStyle(fontWeight: FontWeight.w900, color: riskColor),
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
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Intensity: ${intensity == null ? '—' : intensity!.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
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
                          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                        ),
                      )
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
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
                  Text('Important Note:', style: TextStyle(fontWeight: FontWeight.w900)),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
    );
  }
}

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
  });

  final double? calcium;
  final double? oxalate;
  final double? ph;
  final double? uric;

  final String caStatus;
  final String oxStatus;
  final String phStatus;
  final String uaStatus;

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up.contains('ELEV')) return Colors.orange;
    if (up.contains('HIGH')) return Colors.red;
    if (up.contains('LOW')) return Colors.orange;
    if (up.contains('NORMAL')) return Colors.green;
    return Colors.black54;
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String biomarker, String value, String range, String status) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(biomarker, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(flex: 2, child: Text(value)),
            Expanded(flex: 2, child: Text(range)),
            Expanded(
              flex: 2,
              child: Text(
                status,
                style: TextStyle(fontWeight: FontWeight.w900, color: _statusColor(status)),
              ),
            ),
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
          const Row(
            children: [
              Expanded(flex: 2, child: Text('Biomarker', style: TextStyle(color: Colors.black54))),
              Expanded(flex: 2, child: Text('Value', style: TextStyle(color: Colors.black54))),
              Expanded(flex: 2, child: Text('Normal Range', style: TextStyle(color: Colors.black54))),
              Expanded(flex: 2, child: Text('Status', style: TextStyle(color: Colors.black54))),
            ],
          ),
          const Divider(height: 18),
          // ✅ Use " - " (hyphen) instead of "–" for cleaner PDF fonts too
          row('Calcium', _fmt(calcium, 2, suffix: ' mmol/L'), '2.2 - 2.6', caStatus),
          row('Oxalate', _fmt(oxalate, 2, suffix: ' mmol/L'), '0.0 - 0.40', oxStatus),
          row('pH Level', _fmt(ph, 1), '5.5 - 7.0', phStatus),
          row('Uric Acid', _fmt(uric, 2, suffix: ' mmol/L'), '0.15 - 0.45', uaStatus),
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

        // ✅ keep preview "normal"
        useActions: true,
        allowPrinting: true,
        allowSharing: true,

        // Some printing versions support this (leave commented if it errors):
        // debug: false,
      ),
    );
  }
}

/* --------------------------- CLEAN PDF GENERATION (FAST) --------------------------- */

Future<Uint8List> _buildPdfClean({
  required String name,
  required String email,
  required String uid, // still passed, but not printed
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
  required String? imageUrl, // not fetched (fast)
  required String? rawResult,
  required double? intensity,
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

  // ✅ Monospace for numbers (prevents squished / overlapping look)
  final mono = pw.TextStyle(fontSize: 10, font: pw.Font.courier());

  pw.Widget section(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Text(t, style: h),
      );

  pw.Table biomarkerTable() {
    final th = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700);

    pw.TextStyle statusStyle(String s) {
      final up = s.toUpperCase();
      if (up.contains('HIGH') || up.contains('ELEV')) {
        return pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700);
      }
      if (up.contains('LOW') || up.contains('WARN')) {
        return pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700);
      }
      if (up.contains('NORMAL')) {
        return pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700);
      }
      return pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700);
    }

    pw.TableRow row(String b, String v, String r, String s) => pw.TableRow(
          children: [
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(b, style: small)),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(v, style: mono)),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(r, style: mono)),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(s, style: statusStyle(s))),
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
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Biomarker', style: th)),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Value', style: th)),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Normal Range', style: th)),
            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Status', style: th)),
          ],
        ),
        // ✅ Use " - " (hyphen) instead of "–" (en-dash) to avoid font rendering issues
        row('Calcium', _fmt(calcium, 2, suffix: ' mmol/L'), '2.2 - 2.6', caStatus),
        row('Oxalate', _fmt(oxalate, 2, suffix: ' mmol/L'), '0.0 - 0.40', oxStatus),
        row('pH Level', _fmt(ph, 1), '5.5 - 7.0', phStatus),
        row('Uric Acid', _fmt(uric, 2, suffix: ' mmol/L'), '0.15 - 0.45', uaStatus),
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
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
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
                pw.Text(reportDate, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),

        // Patient info (ONLY name + email)
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
              pw.Text('Overall Risk Level:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(width: 8),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: riskColor),
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  riskLabel,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: riskColor),
                ),
              ),
              pw.Spacer(),
              pw.Text('Raw Result: ', style: muted),
              pw.Text((rawResult == null || rawResult.trim().isEmpty) ? '—' : rawResult.trim(), style: small),
              pw.SizedBox(width: 12),
              pw.Text('Intensity: ', style: muted),
              pw.Text(intensity == null ? '—' : intensity.toStringAsFixed(2), style: mono),
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
            _doctorNotes(oxStatus: oxStatus, riskLabel: riskLabel, rawResult: rawResult, intensity: intensity),
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

/* ------------------------------ helpers ------------------------------ */

DateTime _dtFrom(dynamic ts) {
  try {
    return (ts as dynamic).toDate() as DateTime;
  } catch (_) {
    if (ts is DateTime) return ts;
    return DateTime.now();
  }
}

String _formatReportDate(DateTime dt) => DateFormat("MMMM d, yyyy 'at' h:mm a").format(dt);

String _makeReportId(String uid, DateTime dt) {
  final compact = DateFormat('yyyyMMddHHmmss').format(dt);
  final shortUid = uid.length >= 6 ? uid.substring(0, 6) : uid;
  return 'ES-$shortUid-$compact';
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
  final rr = (rawResult == null || rawResult.trim().isEmpty) ? null : rawResult.trim();

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

// dynamic helpers
String? _dynString(TestResult? t, String field) {
  if (t == null) return null;
  try {
    final dyn = t as dynamic;
    final map = dyn.toMap();
    final v = map[field];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  } catch (_) {}
  return null;
}

double? _dynNum(TestResult? t, String field) {
  if (t == null) return null;
  try {
    final dyn = t as dynamic;
    final map = dyn.toMap();
    final v = map[field];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  } catch (_) {}
  return null;
}