import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/test_result.dart';

class TestService {
  TestService({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Not logged in');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> _testsRef() {
    return _db.collection('users').doc(_uid).collection('tests');
  }

  /// ✅ STEP 1: Save any result (demo now, bluetooth later) to Firestore
  Future<void> saveTest(TestResult result) async {
    await _testsRef().add(result.toMap());
  }

  /// Create a fake result for demo/preview (NOT saved until you call saveTest)
  TestResult generateDemoResult() {
    final rng = Random();

    final calcium = (rng.nextDouble() * 2.0) + 1.0; // 1.0..3.0
    final oxalate = (rng.nextDouble() * 0.8) + 0.1; // 0.1..0.9
    final ph = (rng.nextDouble() * 2.5) + 5.0;      // 5.0..7.5
    final uricAcid = (rng.nextDouble() * 0.6) + 0.1; // 0.1..0.7

    String risk;
    if (oxalate < 0.4) {
      risk = 'NORMAL';
    } else if (oxalate < 0.65) {
      risk = 'WARNING';
    } else {
      risk = 'HIGH';
    }

    return TestResult(
      source: 'demo',
      deviceId: 'ESBUDEN-DEMO',
      overallRisk: risk,
      biomarkers: {
        'calcium': double.parse(calcium.toStringAsFixed(2)),
        'oxalate': double.parse(oxalate.toStringAsFixed(2)),
        'ph': double.parse(ph.toStringAsFixed(1)),
        'uricAcid': double.parse(uricAcid.toStringAsFixed(2)),
      },
    );
  }

  /// Optional convenience: directly add a demo test to history
  Future<void> addDemoTest() async {
    await saveTest(generateDemoResult());
  }

  Stream<TestResult?> watchLatestTest() {
    return _testsRef()
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : TestResult.fromDoc(snap.docs.first));
  }

  Stream<List<TestResult>> watchTests({int limit = 50}) {
    return _testsRef()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TestResult.fromDoc).toList());
  }
}
