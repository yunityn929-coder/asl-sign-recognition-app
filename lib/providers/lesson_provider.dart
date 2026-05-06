import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson_model.dart';
import '../services/firestore_service.dart';

final lessonProvider = StreamProvider.family<List<LessonModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchLessons(uid);
});
