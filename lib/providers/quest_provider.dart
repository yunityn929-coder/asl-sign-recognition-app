import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_quest_model.dart';
import '../services/firestore_service.dart';

final dailyQuestProvider =
    FutureProvider.family.autoDispose<DailyQuestModel?, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).getDailyQuests(uid);
});

final questStreamProvider =
    StreamProvider.family.autoDispose<DailyQuestModel?, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchDailyQuests(uid);
});
