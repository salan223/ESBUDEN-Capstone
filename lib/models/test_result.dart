import 'package:cloud_firestore/cloud_firestore.dart';

class TestResult {
  final String id;
  final DateTime createdAt;
  final String overallRisk;
  final Map<String, dynamic> biomarkers;
  final double intensity;
  final String rawResult;
  final String imageUrl;
  final String imagePath;

  TestResult({
    this.id = '',
    required this.createdAt,
    required this.overallRisk,
    required this.biomarkers,
    required this.intensity,
    required this.rawResult,
    required this.imageUrl,
    required this.imagePath,
  });

  factory TestResult.fromMap(Map<String, dynamic> map, String docId) {
    final createdAtRaw = map['createdAt'];

    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return TestResult(
      id: docId,
      createdAt: createdAt,
      overallRisk: (map['overallRisk'] ?? 'UNKNOWN').toString(),
      biomarkers: Map<String, dynamic>.from(map['biomarkers'] ?? {}),
      intensity: ((map['intensity'] ?? 0) as num).toDouble(),
      rawResult: (map['rawResult'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      imagePath: (map['imagePath'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdAt': Timestamp.fromDate(createdAt),
      'overallRisk': overallRisk,
      'biomarkers': biomarkers,
      'intensity': intensity,
      'rawResult': rawResult,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
    };
  }
}