import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/firestore_service.dart';

final userProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchUser(uid);
});

class UserActions {
  const UserActions(this._service, this._uid);
  final FirestoreService _service;
  final String _uid;

  Future<void> addXp(int amount) => _service.addXp(_uid, amount);
}

final userActionsProvider = Provider.family<UserActions, String>(
  (ref, uid) => UserActions(ref.read(firestoreServiceProvider), uid),
);
