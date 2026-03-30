import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/test_result.dart';
import '../../services/auth_service.dart';

class TestReportDetailPage extends StatelessWidget {
  const TestReportDetailPage({super.key, required this.test});

  final TestResult test;

  // ---------------- UI helpers ----------------

  DateTime _dtFrom(dynamic ts) {
    try {
      return (ts as dynamic).toDate() as DateTime;
    } catch (_) {
      if (ts is DateTime) return ts;
      return DateTime.now();
    }
  }

  String _formatHeaderDate(DateTime dt) => DateFormat('MMM d, yyyy').format(dt);

  String _formatReportDate(DateTime dt) =>
      DateFormat("MMMM d, yyyy 'at' h:mm a").format(dt);

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
    if (up.contains('HIGH')) return 'HIGH';
    if (up.contains('WARN')) return 'WARNING';
    if (up.contains('NORMAL')) return 'NORMAL';
    if (risk.trim().isEmpty || risk.trim() == '—') return '—';
    return risk.toUpperCase();
  }

  Color _riskColor(String riskLabel) {
    final r = riskLabel.toUpperCase();
    if (r.contains('HIGH')) return Colors.red;
    if (r.contains('WARN')) return Colors.orange;
    if (r.contains('NORMAL')) return Colors.green;
    return Colors.grey;
  }

  // Normal ranges from your report UI
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

  Map<String, dynamic> _map(TestResult t) {
    try {
      final dyn = t as dynamic;
      final m = dyn.toMap();
      if (m is Map<String, dynamic>) return m;
    } catch (_) {}
    return {};
  }

  String? _getStringField(String field) {
    final m = _map(test);
    final v = m[field];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  double? _getNumField(String field) {
    final m = _map(test);
    final v = m[field];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  String _doctorNotes({
    required String oxStatus,
    required String riskLabel,
    required String? rawResult,
    required double? intensity,
  }) {
    final oxUp = oxStatus.toUpperCase();
    final riskUp = riskLabel.toUpperCase();
    final rr = (rawResult == null || rawResult.trim().isEmpty)
        ? null
        : rawResult.trim();

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

  String _fileNameFromDate(DateTime dt) {
    final d = DateFormat('yyyy-MM-dd_HHmm').format(dt);
    return 'URI-TRACK_TestReport_$d.pdf';
  }

  String _makeReportId(String uid, DateTime dt) {
    final compact = DateFormat('yyyyMMddHHmmss').format(dt);
    final shortUid = uid.length >= 6 ? uid.substring(0, 6) : uid;
    return 'ES-$shortUid-$compact';
  }

  // ---------------- PDF generation (fast + clean) ----------------

  Future<Uint8List> _buildPdfForThisTest({
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
    required String? rawResult,
    required double? intensity,
    required String? imageUrl, // not embedded for speed
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

          section('Patient Information'),
          pw.Text('Patient Name: $name', style: small),
          pw.SizedBox(height: 4),
          pw.Text('Email: $email', style: small),

          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.grey300),

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
              _doctorNotes(
                oxStatus: oxStatus,
                riskLabel: riskLabel,
                rawResult: rawResult,
                intensity: intensity,
              ),
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

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();

    final dt = _dtFrom(test.createdAt);
    final risk = _riskLabel((test.overallRisk ?? '—').toString());
    final riskColor = _riskColor(risk);

    final calcium = _num(test.biomarkers['calcium']);
    final oxalate = _num(test.biomarkers['oxalate']);
    final ph = _num(test.biomarkers['ph']);
    final uric = _num(test.biomarkers['uricAcid']);

    final caStatus = _statusForCalcium(calcium);
    final oxStatus = _statusForOxalate(oxalate);
    final phStatus = _statusForPH(ph);
    final uaStatus = _statusForUric(uric);

    final imageUrl = _getStringField('imageUrl');
    final rawResult = _getStringField('rawResult');
    final intensity = _getNumField('intensity');

    Future<Uint8List> makePdf() async {
      final user = auth.currentUser;
      final name = user?.displayName ?? 'User';
      final email = user?.email ?? '—';
      final uid = user?.uid ?? '—';

      final reportDate = _formatReportDate(dt);
      final reportId = _makeReportId(uid, dt);

      return _buildPdfForThisTest(
        name: name,
        email: email,
        reportDate: reportDate,
        reportId: reportId,
        riskLabel: risk,
        calcium: calcium,
        oxalate: oxalate,
        ph: ph,
        uric: uric,
        caStatus: caStatus,
        oxStatus: oxStatus,
        phStatus: phStatus,
        uaStatus: uaStatus,
        rawResult: rawResult,
        intensity: intensity,
        imageUrl: imageUrl,
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

        try {
          await Printing.sharePdf(bytes: bytes, filename: _fileNameFromDate(dt));
        } catch (_) {
          await openPreview();
          if (!context.mounted) return;
          _snack(context, 'Sharing may not be available on this emulator. Use share/print inside PDF Preview.');
        }
      } catch (e) {
        if (!context.mounted) return;
        _hideLoading(context);
        _snack(context, 'Failed to export PDF: $e');
      }
    }

    final notes = _doctorNotes(
      oxStatus: oxStatus,
      riskLabel: risk,
      rawResult: rawResult,
      intensity: intensity,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Test Report')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: ListView(
            children: [
              const SizedBox(height: 8),
              Text(
                _formatHeaderDate(dt),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 14),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: riskColor),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            risk,
                            style: TextStyle(fontWeight: FontWeight.w900, color: riskColor),
                          ),
                          const SizedBox(height: 2),
                          const Text('Overall Risk', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Biomarker Results',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      _BioRow(label: 'Calcium', status: caStatus, value: _fmt(calcium, 2, suffix: ' mmol/L'), color: _statusColor(caStatus)),
                      const Divider(),
                      _BioRow(label: 'Oxalate', status: oxStatus, value: _fmt(oxalate, 2, suffix: ' mmol/L'), color: _statusColor(oxStatus)),
                      const Divider(),
                      _BioRow(label: 'pH', status: phStatus, value: _fmt(ph, 1), color: _statusColor(phStatus)),
                      const Divider(),
                      _BioRow(label: 'Uric Acid', status: uaStatus, value: _fmt(uric, 2, suffix: ' mmol/L'), color: _statusColor(uaStatus)),
                      const SizedBox(height: 10),
                      Text(notes, style: const TextStyle(height: 1.3)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: openPreview,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF Preview', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: exportPdf,
                  icon: const Icon(Icons.share),
                  label: const Text('Share / Download PDF', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up.contains('ELEV') || up.contains('WARN')) return Colors.orange;
    if (up.contains('HIGH')) return Colors.red;
    if (up.contains('LOW')) return Colors.orange;
    if (up.contains('NORMAL')) return Colors.green;
    return Colors.black54;
  }
}

class _BioRow extends StatelessWidget {
  const _BioRow({
    required this.label,
    required this.status,
    required this.value,
    required this.color,
  });

  final String label;
  final String status;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ]),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

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