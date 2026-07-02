import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class BaseAuthService {
  Stream<String?> get onAuthStateChanged;
  String? get currentUserUid;
  String? get currentUserEmail;
  String? get currentUserDisplayName;
  Future<String?> signUp(String email, String password);
  Future<String?> signIn(String email, String password);
  Future<String?> signInWithGoogle();
  Future<void> signOut();
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      default:
        return error.message ?? 'Authentication failed.';
    }
  }
  return error.toString().replaceAll('Exception:', '').trim();
}

class FirebaseAuthService implements BaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<String?> get onAuthStateChanged =>
      _firebaseAuth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUserUid => _firebaseAuth.currentUser?.uid;

  @override
  String? get currentUserEmail => _firebaseAuth.currentUser?.email;

  @override
  String? get currentUserDisplayName => _firebaseAuth.currentUser?.displayName;

  @override
  Future<String?> signUp(String email, String password) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user?.uid;
  }

  @override
  Future<String?> signIn(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user?.uid;
  }

  @override
  Future<String?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final credential = await _firebaseAuth.signInWithPopup(provider);
      return credential.user?.uid;
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user?.uid;
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _firebaseAuth.signOut();
  }
}

class LocalMockAuthService implements BaseAuthService {
  final _controller = StreamController<String?>.broadcast();
  String? _currentUid;
  String? _currentEmail;
  String? _currentDisplayName;

  LocalMockAuthService() {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUid = prefs.getString('local_auth_uid');
      _currentEmail = prefs.getString('local_auth_email');
      _currentDisplayName = prefs.getString('local_auth_display_name');
      _controller.add(_currentUid);
    } catch (_) {
      _controller.add(null);
    }
  }

  String _uidFromEmail(String email) =>
      'local_${email.trim().replaceAll('@', '_').replaceAll('.', '_')}';

  @override
  Stream<String?> get onAuthStateChanged => _controller.stream;

  @override
  String? get currentUserUid => _currentUid;

  @override
  String? get currentUserEmail => _currentEmail;

  @override
  String? get currentUserDisplayName => _currentDisplayName;

  @override
  Future<String?> signUp(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidFromEmail(email);
    final normalizedEmail = email.trim().toLowerCase();
    await prefs.setString('local_auth_uid', uid);
    await prefs.setString('local_auth_email', normalizedEmail);
    _currentUid = uid;
    _currentEmail = normalizedEmail;
    _controller.add(uid);
    return uid;
  }

  @override
  Future<String?> signIn(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uidFromEmail(email);
    final normalizedEmail = email.trim().toLowerCase();
    await prefs.setString('local_auth_uid', uid);
    await prefs.setString('local_auth_email', normalizedEmail);
    _currentUid = uid;
    _currentEmail = normalizedEmail;
    _controller.add(uid);
    return uid;
  }

  @override
  Future<String?> signInWithGoogle() async {
    final prefs = await SharedPreferences.getInstance();
    const uid = 'local_google_user';
    const email = 'user@gmail.com';
    await prefs.setString('local_auth_uid', uid);
    await prefs.setString('local_auth_email', email);
    await prefs.setString('local_auth_display_name', 'Google User');
    _currentUid = uid;
    _currentEmail = email;
    _currentDisplayName = 'Google User';
    _controller.add(uid);
    return uid;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_auth_uid');
    await prefs.remove('local_auth_email');
    await prefs.remove('local_auth_display_name');
    _currentUid = null;
    _currentEmail = null;
    _currentDisplayName = null;
    _controller.add(null);
  }
}
