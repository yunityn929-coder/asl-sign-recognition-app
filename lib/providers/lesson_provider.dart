import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson_model.dart';
import '../services/firestore_service.dart';

final lessonProvider = StreamProvider.family.autoDispose<List<LessonModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchLessons(uid);
});

class LessonActions {
  const LessonActions(this._service, this._uid);
  final FirestoreService _service;
  final String _uid;

  Future<void> markLessonComplete(String lessonId) =>
      _service.markLessonComplete(_uid, lessonId);
}

final lessonActionsProvider = Provider.family.autoDispose<LessonActions, String>(
  (ref, uid) => LessonActions(ref.read(firestoreServiceProvider), uid),
);
