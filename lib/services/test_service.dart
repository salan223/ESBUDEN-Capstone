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

  Future<void> addDemoTest() async {
    final rng = Random();

    final oxalate = (rng.nextDouble() * 20) + 5; // 5..25
    final ph = (rng.nextDouble() * 2.5) + 5.0;   // 5.0..7.5
    final protein = rng.nextDouble() * 30;       // 0..30

    String risk;
    if (oxalate < 12 && protein < 10) {
      risk = 'NORMAL';
    } else if (oxalate < 18) {
      risk = 'WARNING';
    } else {
      risk = 'HIGH';
    }

    final result = TestResult(
      source: 'demo',
      deviceId: 'ESBUDEN-DEMO',
      overallRisk: risk,
      biomarkers: {
        'oxalate': double.parse(oxalate.toStringAsFixed(1)),
        'ph': double.parse(ph.toStringAsFixed(1)),
        'protein': double.parse(protein.toStringAsFixed(1)),
      },
    );

    await _testsRef().add(result.toMap());
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
