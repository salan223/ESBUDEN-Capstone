import 'package:cloud_firestore/cloud_firestore.dart';

class TestResult {
  final String? id;
  final DateTime? createdAt;
  final String source; // demo | bluetooth
  final String? deviceId;

  final String overallRisk; // NORMAL | WARNING | HIGH
  final Map<String, dynamic> biomarkers;

  TestResult({
    this.id,
    this.createdAt,
    required this.source,
    this.deviceId,
    required this.overallRisk,
    required this.biomarkers,
  });

  Map<String, dynamic> toMap() => {
        'createdAt': FieldValue.serverTimestamp(),
        'source': source,
        'deviceId': deviceId,
        'overallRisk': overallRisk,
        'biomarkers': biomarkers,
      };

  static TestResult fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    return TestResult(
      id: doc.id,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      source: (data['source'] ?? 'unknown') as String,
      deviceId: data['deviceId'] as String?,
      overallRisk: (data['overallRisk'] ?? 'UNKNOWN') as String,
      biomarkers: Map<String, dynamic>.from(data['biomarkers'] ?? {}),
    );
  }
}
