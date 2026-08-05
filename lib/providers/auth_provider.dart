import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// userChanges() rather than authStateChanges() — the latter misses provider
// link/unlink, which would leave isAnonymous-driven UI stale after one.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});
