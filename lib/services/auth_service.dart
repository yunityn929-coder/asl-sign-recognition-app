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

  // Always fully signs out to a brand-new guest session, regardless of how
  // the account was reached (linked in-place from this device's own guest
  // session, or signed into a separate existing account). Progress isn't
  // lost — it stays in Firestore under that account's uid — but this device
  // doesn't auto-resume it; signing back into the same Google account
  // recovers it.
  Future<void> signOut() async {
    // Best-effort only — some environments leave this hanging indefinitely
    // with no exception and no UI (a stale native session with nothing to
    // disconnect), which would otherwise stall the entire sign-out below.
    try {
      await _googleSignIn.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {}
    await _auth.signOut();
  }

  // Returns the signed-in User (plus the Google account's own display name,
  // email, and photo URL), or nulls if the user cancelled the picker. Throws
  // AuthException on actual failures.
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

  // Signs directly into the target Google account, swapping the active
  // session rather than merging into the current anonymous user (contrast
  // with linkWithGoogle()'s upgrade-in-place behaviour). Returns whether the
  // account was genuinely new to Firebase so callers can decide whether a
  // Firestore user doc needs bootstrapping.
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

  // Prompts for a fresh Google credential when the session isn't anonymous,
  // so a stale session can't cause deleteAccount() to hit requires-recent-login
  // *after* the caller has already deleted the user's Firestore data. Callers
  // must run this — and let it succeed — before deleting any Firestore data,
  // then call deleteAccount() immediately after. No-op for anonymous users.
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

  // Deletes the Firebase Auth account. The local session — and therefore
  // Firestore write permission for this uid — disappears the instant this
  // succeeds, so callers must delete Firestore data first and call
  // reauthenticateForDeleteIfNeeded() before that, not after this.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No signed-in user.');
    debugPrint('[TEMP DEBUG] deleteAccount: starting for uid=${user.uid}');

    // This device has been observed to silently hang Firebase network calls
    // with no exception (see the disconnect() fix above), so this must
    // surface a real error on timeout rather than fail silently.
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
