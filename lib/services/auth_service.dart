import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ✅ NEW: stream the Firestore user doc (users/{uid})
  Stream<Map<String, dynamic>?> userDocStream() {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data());
  }

  // ✅ NEW: stream only the name from Firestore (users/{uid}.name)
  Stream<String?> userNameStream() {
    return userDocStream().map((data) => data?['name'] as String?);
  }

  /// Creates Firebase Auth user + creates/merges Firestore user profile.
  /// Returns the created User.
  Future<User> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'User creation failed. Please try again.',
        );
      }

      // Optional but useful: store name in FirebaseAuth profile too
      await user.updateDisplayName(name.trim());

      // Save user profile (never save passwords)
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return user;
    } on FirebaseAuthException catch (e) {
      // Re-throw with friendlier messages for UI
      throw FirebaseAuthException(code: e.code, message: friendlyAuthError(e));
    }
  }

  /// Signs in and returns the signed-in User.
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Login failed. Please try again.',
        );
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(code: e.code, message: friendlyAuthError(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// Helper: Map Firebase errors into messages you can show in the UI.
  String friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'That email is already registered. Try logging in.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid login details. Double-check and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in Firebase console.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
