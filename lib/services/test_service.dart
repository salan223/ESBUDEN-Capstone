import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/test_result.dart';

class TestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No logged-in user found');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _testsRef {
    return _firestore.collection('users').doc(_uid).collection('tests');
  }

  Future<void> saveTest(TestResult result) async {
    await _testsRef.add(result.toMap());
  }

  Stream<TestResult?> watchLatestTest() {
    return _testsRef
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return TestResult.fromMap(doc.data(), doc.id);
    });
  }

  Stream<List<TestResult>> watchTests({int limit = 20}) {
    return _testsRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TestResult.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addDemoTest() async {
    final demo = generateDemoResult();
    await saveTest(demo);
  }

  TestResult generateDemoResult() {
    return TestResult(
      createdAt: DateTime.now(),
      overallRisk: 'NORMAL',
      biomarkers: {
        'calcium': 0.0,
        'oxalate': 0.0,
        'ph': 0.0,
        'uricAcid': 0.0,
      },
      intensity: 100.0,
      rawResult: 'Demo',
      imageUrl: '',
      imagePath: '',
    );
  }
}