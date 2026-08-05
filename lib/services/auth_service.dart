import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/errors/app_exception.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<User> signInSilently() async {
    if (_auth.currentUser != null) {
      debugPrint('[TEMP DEBUG] signInSilently: reusing existing currentUser uid=${_auth.currentUser!.uid}');
      return _auth.currentUser!;
    }
    try {
      final cred = await _auth.signInAnonymously();
      debugPrint('[TEMP DEBUG] signInSilently: created NEW anonymous uid=${cred.user!.uid}');
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Anonymous sign-in failed');
    }
  }

  // Always signs out to a brand-new guest session. Progress isn't lost, it
  // stays in Firestore under the old uid, but this device won't auto-resume
  // it until signing back into the same Google account.
  Future<void> signOut() async {
    // Best-effort — some environments leave this hanging with no exception,
    // which would otherwise stall the whole sign-out.
    try {
      await _googleSignIn.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _auth.signOut();
  }

  // Returns nulls if the user cancelled the picker, otherwise the linked
  // user plus their Google display name/email/photo. Throws on real failures.
  Future<({User? user, String? googleDisplayName, String? googleEmail, String? googlePhotoUrl})> linkWithGoogle() async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) {
      throw const AuthException(
          "You're already signed in. Sign out first if you want to link a different account.");
    }

    await GoogleSignIn().signOut();
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      return (user: null, googleDisplayName: null, googleEmail: null, googlePhotoUrl: null); // user dismissed the picker
    }

    try {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link to preserve all Firestore data under this UID.
      final result = await current.linkWithCredential(credential);
      return (
        user: result.user,
        googleDisplayName: googleUser.displayName,
        googleEmail: googleUser.email,
        googlePhotoUrl: googleUser.photoUrl,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[TEMP DEBUG] linkWithGoogle FirebaseAuthException: code=${e.code}, message=${e.message}');
      throw AuthException(_friendly(e.code));
    }
  }

  // Swaps to the target Google account instead of merging into the current
  // anonymous user like linkWithGoogle() does. isNewUser tells the caller
  // whether a Firestore user doc still needs bootstrapping.
  Future<({User? user, bool isNewUser})> signInWithGoogle() async {
    await GoogleSignIn().signOut();
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return (user: null, isNewUser: false); // user dismissed the picker

    try {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      return (
        user: result.user,
        isNewUser: result.additionalUserInfo?.isNewUser ?? false,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendly(e.code));
    }
  }

  // Gets a fresh Google credential before deleteAccount(), so a stale session
  // can't hit requires-recent-login after Firestore data is already deleted.
  // Must succeed before deleting Firestore data. No-op for anonymous users.
  Future<void> reauthenticateForDeleteIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No signed-in user.');
    if (user.isAnonymous) return;

    debugPrint('[TEMP DEBUG] reauthenticateForDeleteIfNeeded: starting GoogleSignIn().signIn()');
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      debugPrint('[TEMP DEBUG] reauthenticateForDeleteIfNeeded: signIn() returned null (cancelled)');
      throw const AuthException('Re-authentication cancelled.');
    }
    debugPrint('[TEMP DEBUG] reauthenticateForDeleteIfNeeded: signIn() ok, getting authentication');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      debugPrint('[TEMP DEBUG] reauthenticateForDeleteIfNeeded: calling reauthenticateWithCredential');
      await user.reauthenticateWithCredential(credential);
      debugPrint('[TEMP DEBUG] reauthenticateForDeleteIfNeeded: reauthenticateWithCredential SUCCEEDED');
    } on FirebaseAuthException catch (e) {
      debugPrint('[TEMP DEBUG] reauthenticateForDeleteIfNeeded: FirebaseAuthException code=${e.code}');
      throw AuthException(_friendly(e.code));
    }
  }

  // Firestore write permission for this uid dies the instant this succeeds,
  // so callers must delete Firestore data first, and reauthenticate before that.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No signed-in user.');
    debugPrint('[TEMP DEBUG] deleteAccount: starting for uid=${user.uid}');

    // This device has been seen to silently hang here with no exception, so
    // surface a real error on timeout instead of failing silently.
    try {
      debugPrint('[TEMP DEBUG] deleteAccount: calling user.delete()');
      await user.delete().timeout(const Duration(seconds: 15));
      debugPrint('[TEMP DEBUG] deleteAccount: user.delete() SUCCEEDED, currentUser now = ${_auth.currentUser?.uid ?? "null"}');
    } on FirebaseAuthException catch (e) {
      debugPrint('[TEMP DEBUG] deleteAccount: user.delete() FirebaseAuthException code=${e.code} message=${e.message}');
      throw AuthException(_friendly(e.code));
    } on TimeoutException {
      debugPrint('[TEMP DEBUG] deleteAccount: user.delete() TIMED OUT after 15s');
      throw const AuthException(
          'Deleting your account is taking longer than expected. Please check your connection and try again.');
    }
  }

  static String _friendly(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'This Google account is linked to a different sign-in method.';
      case 'credential-already-in-use':
        return 'This Google account is already linked to another profile.';
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
