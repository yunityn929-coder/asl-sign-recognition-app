import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/errors/app_exception.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<User> signInSilently() async {
    if (_auth.currentUser != null) return _auth.currentUser!;
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Anonymous sign-in failed');
    }
  }

  Future<User> linkWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw const AuthException('Google sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.currentUser!.linkWithCredential(credential);
      return result.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Google link failed');
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
