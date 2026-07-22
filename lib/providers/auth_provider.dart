import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// userChanges() rather than authStateChanges() — the latter only fires on
// real sign-in/out transitions and misses provider link/unlink (e.g.
// AuthService.signOut()'s unlink-to-preserve-data path), which would leave
// isAnonymous-driven UI stale after an unlink.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});
