import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/xp_constants.dart';
import '../core/errors/app_exception.dart';
import '../data/lesson_definitions.dart';
import '../data/quest_pool.dart';
import '../models/daily_quest_model.dart';
import '../models/lesson_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUser(String uid) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final today = _today();
    try {
      await ref.set({
        'uid': uid,
        'displayName': 'Learner',
        'email': '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActiveDate': today,
        'isAnonymous': true,
        'authProvider': 'anonymous',
        'onboardingComplete': false,
        'aslLevel': '',
        'dailyGoalMinutes': 5,
        'notificationsEnabled': false,
        'startLessonId': 's1l1',
        'currentStreak': 0,
        'longestStreak': 0,
        'lastStreakDate': '',
        'totalXp': 0,
        'ttsEnabled': true,
        'soundEnabled': true,
        'calibrationEnabled': true,
        'streakGoalDays': 7,
        'streakGoalStartDate': '',
        'streakGoalAchieved': false,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FirestorePermissionException('Permission denied. Deploy Firestore security rules.');
      }
      throw FirestoreException(e.message ?? 'Failed to create user');
    }
  }

  Future<UserModel?> getUserOnce(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      return UserModel.fromMap(uid, _normalise(snap.data()!));
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to read user');
    }
  }

  Stream<UserModel?> watchUser(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((snap) =>
          snap.exists ? UserModel.fromMap(uid, _normalise(snap.data()!)) : null);

  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    try {
      await _db.collection('users').doc(uid).set(fields, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FirestorePermissionException('Permission denied. Deploy Firestore security rules.');
      }
      throw FirestoreException(e.message ?? 'Failed to update user');
    }
  }

  Stream<List<LessonModel>> watchLessons(String uid) =>
      _db.collection('users').doc(uid).collection('lessons').snapshots().asyncMap(
            (snap) async {
              final lessons = snap.docs
                  .map((d) => LessonModel.fromMap(_normaliseLesson(d.data())))
                  .toList();
              return _reconcileLessons(uid, lessons);
            },
          );

  // Corrects data corrupted by a pre-fix markLessonComplete bug where
  // replaying an already-completed lesson could regress a later lesson from
  // 'completed' back to 'available', leaving two lessons simultaneously
  // 'available'. The highest-index 'available' lesson is the true frontier —
  // anything before it must have been genuinely completed at some point,
  // since that's the only way a later lesson could have been unlocked.
  Future<List<LessonModel>> _reconcileLessons(
    String uid,
    List<LessonModel> lessons,
  ) async {
    final availableIds =
        lessons.where((l) => l.status == 'available').map((l) => l.lessonId).toList();
    if (availableIds.length <= 1) return lessons;

    final availableIndices = availableIds
        .map((id) => kLessons.indexWhere((l) => l.id == id))
        .where((i) => i >= 0)
        .toList()
      ..sort();
    final frontierIdx = availableIndices.last;
    final staleIds = availableIds
        .where((id) => kLessons.indexWhere((l) => l.id == id) != frontierIdx)
        .toSet();

    final lessonsRef = _db.collection('users').doc(uid).collection('lessons');
    final batch = _db.batch();
    for (final id in staleIds) {
      batch.set(lessonsRef.doc(id), {'status': 'completed'}, SetOptions(merge: true));
    }
    try {
      await batch.commit();
    } on FirebaseException catch (_) {
      return lessons; // best-effort — surface uncorrected data rather than throw
    }

    return [
      for (final l in lessons)
        staleIds.contains(l.lessonId) ? l.copyWith(status: 'completed') : l,
    ];
  }

  Map<String, dynamic> _normaliseLesson(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    if (map['completedAt'] is Timestamp) {
      map['completedAt'] =
          (map['completedAt'] as Timestamp).toDate().toIso8601String().substring(0, 10);
    } else if (map['completedAt'] == null) {
      map.remove('completedAt');
    }
    return map;
  }

  // Writes lesson docs for all lessons; marks lessons before startLessonId as
  // completed and the startLessonId lesson as available. All others are locked.
  Future<void> initLessons(String uid, String startLessonId) async {
    final batch = _db.batch();
    final lessonsRef = _db.collection('users').doc(uid).collection('lessons');
    final startIdx = kLessons.indexWhere((l) => l.id == startLessonId);
    for (var i = 0; i < kLessons.length; i++) {
      final lesson = kLessons[i];
      final status = i < startIdx
          ? 'completed'
          : i == startIdx
              ? 'available'
              : 'locked';
      batch.set(lessonsRef.doc(lesson.id), {
        'lessonId': lesson.id,
        'sectionNumber': lesson.section,
        'status': status,
        'completedAt': i < startIdx ? FieldValue.serverTimestamp() : null,
        'practiceCount': 0,
        'bestAccuracy': 0.0,
        'totalXpEarned': 0,
      });
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to init lessons');
    }
  }

  // Converts Firestore Timestamp fields to ISO date strings before deserialization.
  Map<String, dynamic> _normalise(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    if (map['createdAt'] is Timestamp) {
      map['createdAt'] =
          (map['createdAt'] as Timestamp).toDate().toIso8601String().substring(0, 10);
    }
    return map;
  }

  Future<void> markLessonComplete(String uid, String lessonId) async {
    final lessonsRef = _db.collection('users').doc(uid).collection('lessons');

    // A replay of an already-completed lesson must not re-advance the next
    // lesson to 'available' — that would regress it from 'completed' back to
    // 'available' if the user has since progressed past it, producing two
    // simultaneously-available (tooltip-showing) lessons.
    bool alreadyCompleted = false;
    try {
      final existing = await lessonsRef.doc(lessonId).get();
      alreadyCompleted = existing.data()?['status'] == 'completed';
    } on FirebaseException catch (_) {}

    final batch = _db.batch();
    batch.set(lessonsRef.doc(lessonId),
        {'status': 'completed', 'completedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    if (!alreadyCompleted) {
      final idx = kLessons.indexWhere((l) => l.id == lessonId);
      if (idx >= 0 && idx < kLessons.length - 1) {
        batch.set(lessonsRef.doc(kLessons[idx + 1].id), {'status': 'available'},
            SetOptions(merge: true));
      }
      final signCount = idx >= 0 ? kLessons[idx].signs.length : 0;
      if (signCount > 0) {
        batch.update(_db.collection('users').doc(uid),
            {'signsLearned': FieldValue.increment(signCount)});
      }
    }
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to complete lesson');
    }
  }

  Future<void> unlockPractice(String uid, String lessonId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('lessons')
          .doc(lessonId)
          .set({'practiceUnlocked': true}, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const FirestorePermissionException('Permission denied.');
      }
      throw FirestoreException(e.message ?? 'Failed to unlock practice');
    }
  }

  Future<void> saveSignProgress(String uid, String lessonId, int signIndex) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('lessons')
          .doc(lessonId)
          .set({'lastSignIndex': signIndex}, SetOptions(merge: true));
    } on FirebaseException catch (_) {}
  }

  Future<void> saveQuizBestScore(String uid, String quizSetId, int score) async {
    try {
      await _db.collection('users').doc(uid).update({
        'quizBestScores.$quizSetId': score,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const FirestorePermissionException('Permission denied.');
      }
      // Silent fail — best score save is best-effort
    }
  }

  Future<void> addXp(String uid, int amount) async {
    try {
      await _db.collection('users').doc(uid).update(
          {'totalXp': FieldValue.increment(amount)});
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to add XP');
    }
    await updateStreakIfNeeded(uid);
  }

  Future<void> updateStreakIfNeeded(String uid) async {
    final today = _today();
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    try {
      await _db.runTransaction((txn) async {
        final ref = _db.collection('users').doc(uid);
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final data = snap.data()!;
        final lastDate = data['lastStreakDate'] as String? ?? '';
        if (lastDate == today) return;
        final cur = (data['currentStreak'] as num?)?.toInt() ?? 0;
        final longest = (data['longestStreak'] as num?)?.toInt() ?? 0;
        final totalXp = (data['totalXp'] as num?)?.toInt() ?? 0;
        final goalAchieved = data['streakGoalAchieved'] as bool? ?? false;
        final newStreak = lastDate == yesterday ? cur + 1 : 1;

        final update = <String, dynamic>{
          'currentStreak': newStreak,
          'longestStreak': newStreak > longest ? newStreak : longest,
          'lastStreakDate': today,
        };

        if (newStreak >= 7 && !goalAchieved) {
          update['totalXp'] = totalXp + kXpStreakBonus;
          update['streakGoalAchieved'] = true;
        } else if (newStreak <= 1) {
          update['streakGoalAchieved'] = false;
        }

        txn.update(ref, update);
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to update streak');
    }
  }

  Future<Map<String, Map<String, int>>> savePracticeResult({
    required String uid,
    required String lessonId,
    required int correctCount,
    required int totalCount,
    required List<String> missedSigns,
    required int xpEarned,
    required List<String> lessonSigns,
    Map<String, int> learnAttempts = const {},
    String sessionType = 'learn',
  }) async {
    final signAttempts = <String, Map<String, int>>{};
    for (final sign in lessonSigns) {
      final isCorrect = !missedSigns.contains(sign);
      signAttempts[sign] = {
        'correct': isCorrect ? 1 : 0,
        'total': 1,
      };
    }
    final accuracyPercent =
        totalCount == 0 ? 0.0 : correctCount / totalCount * 100;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('practiceResults')
          .add({
        'lessonId': lessonId,
        'sessionType': sessionType,
        'difficulty': 'n/a',
        'completedAt': FieldValue.serverTimestamp(),
        'durationSeconds': 0,
        'totalItems': totalCount,
        'correctCount': correctCount,
        'accuracyPercent': accuracyPercent,
        'xpEarned': xpEarned,
        'items': [],
      });
    } on FirebaseException catch (_) {}
    return signAttempts;
  }

  Future<void> updateSignAccuracy({
    required String uid,
    required Map<String, Map<String, int>> newAccuracy,
  }) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final raw = snap.data()?['signAccuracy'] as Map?;
      final current = (raw ?? {}).map((k, v) => MapEntry(
          k as String,
          Map<String, int>.from((v as Map? ?? {})
              .map((mk, mv) => MapEntry(mk as String, (mv as num).toInt())))));
      final merged = Map<String, Map<String, int>>.from(current);
      for (final entry in newAccuracy.entries) {
        final existing = current[entry.key] ?? {'correct': 0, 'total': 0};
        merged[entry.key] = {
          'correct': (existing['correct'] ?? 0) + (entry.value['correct'] ?? 0),
          'total': (existing['total'] ?? 0) + (entry.value['total'] ?? 0),
        };
      }
      await updateUser(uid, {'signAccuracy': merged});
    } on FirebaseException catch (_) {
    } catch (_) {}
  }

  Future<void> saveCalibrationSample(
      String uid, String signLabel, List<List<double>> samples) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('calibration')
          .doc(signLabel)
          .set({
        'samples': samples.map((s) => {'v': s}).toList(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const FirestorePermissionException('Permission denied.');
      }
      throw FirestoreException(e.message ?? 'Failed to save calibration sample');
    }
  }

  Future<Map<String, List<List<double>>>> loadAllCalibration(String uid) async {
    try {
      final snap =
          await _db.collection('users').doc(uid).collection('calibration').get();
      final result = <String, List<List<double>>>{};
      for (final doc in snap.docs) {
        final raw = doc.data()['samples'] as List?;
        if (raw == null) continue;
        result[doc.id] = raw
            .map((e) => ((e as Map)['v'] as List)
                .map((v) => (v as num).toDouble())
                .toList())
            .toList();
      }
      return result;
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to load calibration');
    }
  }

  Future<void> clearCalibrationClass(String uid, String signLabel) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('calibration')
          .doc(signLabel)
          .delete();
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to clear calibration class');
    }
  }

  Future<void> clearAllCalibration(String uid) async {
    try {
      final ref = _db.collection('users').doc(uid).collection('calibration');
      final snap = await ref.get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to clear calibration');
    }
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  CollectionReference<Map<String, dynamic>> _questsRef(String uid) =>
      _db.collection('users').doc(uid).collection('dailyQuests');

  Map<String, dynamic> _normaliseDailyQuest(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    if (map['generatedAt'] is Timestamp) {
      map['generatedAt'] =
          (map['generatedAt'] as Timestamp).toDate().toIso8601String().substring(0, 10);
    } else if (map['generatedAt'] == null) {
      map['generatedAt'] = _today();
    }
    return map;
  }

  Future<DailyQuestModel?> getDailyQuests(String uid) async {
    final today = _today();
    try {
      final ref = _questsRef(uid).doc(today);
      final snap = await ref.get();
      if (snap.exists) {
        final daily = DailyQuestModel.fromMap(_normaliseDailyQuest(snap.data()!));
        final reconciled = _reconcileQuests(daily.quests);
        if (identical(reconciled, daily.quests)) return daily;
        final updated = daily.copyWith(quests: reconciled);
        await ref.set(updated.toMap(), SetOptions(merge: true));
        return updated;
      }
      return _generateDailyQuests(uid, today);
    } on FirebaseException catch (_) {
      return null;
    }
  }

  // Rebuilds the stored quest list against the current kQuestPool whenever
  // they've drifted (e.g. the fixed quest set changed after today's doc was
  // already generated) — preserves progress for quests whose type/target is
  // unchanged, drops any quest type no longer in the pool. Returns the same
  // list instance untouched when already up to date.
  List<QuestModel> _reconcileQuests(List<QuestModel> stored) {
    final byType = {for (final q in stored) q.type: q};
    final upToDate = stored.length == kQuestPool.length &&
        kQuestPool.every((def) => byType[def.type]?.target == def.target);
    if (upToDate) return stored;

    return [
      for (var i = 0; i < kQuestPool.length; i++)
        _reconciledQuest(i, byType),
    ];
  }

  QuestModel _reconciledQuest(int index, Map<String, QuestModel> byType) {
    final def = kQuestPool[index];
    final existing = byType[def.type];
    final progress =
        existing != null && existing.target == def.target ? existing.progress : 0;
    return QuestModel(
      id: 'quest_$index',
      type: def.type,
      description: def.description,
      target: def.target,
      progress: progress,
      completed: progress >= def.target,
      xpReward: def.xpReward,
    );
  }

  Future<DailyQuestModel?> _generateDailyQuests(String uid, String dateStr) async {
    final quests = [
      for (var i = 0; i < kQuestPool.length; i++)
        QuestModel(
          id: 'quest_$i',
          type: kQuestPool[i].type,
          description: kQuestPool[i].description,
          target: kQuestPool[i].target,
          progress: 0,
          completed: false,
          xpReward: kQuestPool[i].xpReward,
        ),
    ];

    final daily = DailyQuestModel(
      date: dateStr,
      generatedAt: dateStr,
      quests: quests,
      totalQuestsCompleted: 0,
    );

    try {
      await _questsRef(uid).doc(dateStr).set({
        ...daily.toMap(),
        'generatedAt': FieldValue.serverTimestamp(),
      });
      return daily;
    } on FirebaseException catch (_) {
      return null;
    }
  }

  Future<void> updateQuestProgress(String uid, String questType, int amount) async {
    final ref = _questsRef(uid).doc(_today());
    try {
      await _db.runTransaction((txn) async {
        final snap = await txn.get(ref);
        if (!snap.exists) return;
        final daily = DailyQuestModel.fromMap(_normaliseDailyQuest(snap.data()!));

        final updatedQuests = daily.quests.map((q) {
          if (q.type != questType || q.completed) return q;
          final newProgress = q.progress + amount;
          return q.copyWith(
            progress: newProgress,
            completed: newProgress >= q.target,
          );
        }).toList();

        final totalCompleted = updatedQuests.where((q) => q.completed).length;

        txn.update(ref, {
          'quests': updatedQuests.map((q) => q.toMap()).toList(),
          'totalQuestsCompleted': totalCompleted,
        });
      });
    } on FirebaseException catch (_) {
      return;
    }
  }

  Stream<DailyQuestModel?> watchDailyQuests(String uid) {
    return _questsRef(uid).doc(_today()).snapshots().map((snap) =>
        snap.exists ? DailyQuestModel.fromMap(_normaliseDailyQuest(snap.data()!)) : null);
  }
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
