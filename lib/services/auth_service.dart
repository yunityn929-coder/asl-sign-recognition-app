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

  // Returns the signed-in User, or null if the user cancelled the picker.
  // Throws AuthException on actual failures.
  Future<User?> linkWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user dismissed the picker

    try {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        // Link to preserve all Firestore data under this UID.
        final result = await current.linkWithCredential(credential);
        return result.user;
      } else {
        final result = await _auth.signInWithCredential(credential);
        return result.user;
      }
    } on FirebaseAuthException catch (e) {
      // The Google account is already tied to a different Firebase UID.
      // Fall through to sign in with that existing account.
      if (e.code == 'credential-already-in-use' && e.credential != null) {
        try {
          final result = await _auth.signInWithCredential(e.credential!);
          return result.user;
        } on FirebaseAuthException catch (inner) {
          throw AuthException(_friendly(inner.code));
        }
      }
      throw AuthException(_friendly(e.code));
    }
  }

  static String _friendly(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This Google account is linked to a different sign-in method.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'sign_in_failed':
        return 'Google Sign-In failed. Check your internet connection.';
      case 'invalid-credential':
        return 'Sign-in credential expired. Please try again.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
