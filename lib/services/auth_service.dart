import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  // Records the uid of an account that was just linked in-place from THIS
  // device's own anonymous session (see linkWithGoogle()) — the only case
  // where signOut() should unlink-and-preserve instead of fully signing out.
  // Deliberately NOT derived from "the first anonymous uid this device ever
  // saw": that went stale across sign-in/sign-out cycles and caused signOut()
  // to guess wrong (e.g. unlinking — and silently keeping the same session —
  // for an account that was actually reached via signInWithGoogle()'s
  // swap-to-a-different-existing-account flow, not a same-device link).
  static const _linkedFromGuestUidKey = 'linked_from_guest_uid';

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

  Future<void> signOut() async {
    final current = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final linkedFromGuestUid = prefs.getString(_linkedFromGuestUidKey);
    // Best-effort only — some environments leave this hanging indefinitely
    // with no exception and no UI (a stale native session with nothing to
    // disconnect), which would otherwise stall the entire sign-out below.
    try {
      await _googleSignIn.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (current != null &&
        !current.isAnonymous &&
        linkedFromGuestUid != null &&
        current.uid == linkedFromGuestUid) {
      // This account was linked in-place from this device's own anonymous
      // session — unlink instead of full sign-out to preserve all progress.
      try {
        await current.unlink('google.com');
        await prefs.remove(_linkedFromGuestUidKey);
        return;
      } on FirebaseAuthException catch (_) {
        // Fall through to full sign-out if unlink fails for any reason.
      }
    }
    await prefs.remove(_linkedFromGuestUidKey);
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
      if (result.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_linkedFromGuestUidKey, result.user!.uid);
      }
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

    final blockedDoc = await FirebaseFirestore.instance
        .collection('deletedGoogleAccounts')
        .doc(googleUser.id)
        .get();
    if (blockedDoc.exists) {
      throw const AuthException(
        'This Google account was previously deleted from HiASL and can no longer sign in. You can create a new profile instead.',
      );
    }

    try {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      // This swaps to a different, already-existing account — it is never
      // "this device's own guest session merged in place", even if that
      // marker happens to be set from an earlier link on this device.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_linkedFromGuestUidKey);
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

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw const AuthException('Re-authentication cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
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
    try {
      await _recordDeletedGoogleAccount(user);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      await _rollbackDeletedGoogleAccountRecord(user);
      throw AuthException(_friendly(e.code));
    }
  }

  // Marks a deleted account's Google identity as blocked so signInWithGoogle()
  // can refuse it later (see the deletedGoogleAccounts lookup there). Only
  // recorded for accounts that actually had a linked google.com provider.
  // Must run BEFORE user.delete() — the write requires an authenticated
  // request, and delete() clears the session.
  Future<void> _recordDeletedGoogleAccount(User user) async {
    final hasGoogleProvider =
        user.providerData.any((p) => p.providerId == 'google.com');
    if (!hasGoogleProvider) return;
    final googleUid = user.providerData
        .firstWhere((p) => p.providerId == 'google.com')
        .uid;
    await FirebaseFirestore.instance
        .collection('deletedGoogleAccounts')
        .doc(googleUid)
        .set({'deletedAt': FieldValue.serverTimestamp(), 'firebaseUid': user.uid});
  }

  // Best-effort undo of _recordDeletedGoogleAccount() when delete() ends up
  // failing or being cancelled after the record was already written, so a
  // still-live account isn't incorrectly blocklisted.
  Future<void> _rollbackDeletedGoogleAccountRecord(User user) async {
    try {
      final hasGoogleProvider =
          user.providerData.any((p) => p.providerId == 'google.com');
      if (!hasGoogleProvider) return;
      final googleUid = user.providerData
          .firstWhere((p) => p.providerId == 'google.com')
          .uid;
      await FirebaseFirestore.instance
          .collection('deletedGoogleAccounts')
          .doc(googleUid)
          .delete();
    } catch (_) {
      // Best-effort only — don't let rollback failure mask the original error.
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
