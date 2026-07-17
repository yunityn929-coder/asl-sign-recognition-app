import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../data/lesson_definitions.dart';
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
      await _db.collection('users').doc(uid).update(fields);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw FirestorePermissionException('Permission denied. Deploy Firestore security rules.');
      }
      throw FirestoreException(e.message ?? 'Failed to update user');
    }
  }

  Stream<List<LessonModel>> watchLessons(String uid) =>
      _db.collection('users').doc(uid).collection('lessons').snapshots().map(
            (snap) => snap.docs
                .map((d) => LessonModel.fromMap(_normaliseLesson(d.data())))
                .toList(),
          );

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
    final batch = _db.batch();
    final lessonsRef = _db.collection('users').doc(uid).collection('lessons');
    batch.set(lessonsRef.doc(lessonId),
        {'status': 'completed', 'completedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
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
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to complete lesson');
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
        final newStreak = lastDate == yesterday ? cur + 1 : 1;
        txn.update(ref, {
          'currentStreak': newStreak,
          'longestStreak': newStreak > longest ? newStreak : longest,
          'lastStreakDate': today,
        });
      });
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Failed to update streak');
    }
  }

  Future<Map<String, double>> savePracticeResult({
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
    final signAccuracy = <String, double>{};
    for (final sign in lessonSigns) {
      final quizResult = missedSigns.contains(sign) ? 0.0 : 1.0;
      final attempts = learnAttempts[sign] ?? 0;
      // Cap at 5 sustained-correct frames in learn mode = full confidence.
      final learnScore = (attempts / 5).clamp(0.0, 1.0).toDouble();
      signAccuracy[sign] = 0.6 * quizResult + 0.4 * learnScore;
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
    return signAccuracy;
  }

  Future<void> updateSignAccuracy({
    required String uid,
    required Map<String, double> newAccuracy,
  }) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      final raw = snap.data()?['signAccuracy'] as Map?;
      final current = (raw ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      final merged = Map<String, double>.from(current);
      for (final entry in newAccuracy.entries) {
        final existing = current[entry.key];
        merged[entry.key] =
            existing != null ? 0.7 * existing + 0.3 * entry.value : entry.value;
      }
      await updateUser(uid, {'signAccuracy': merged});
    } on FirebaseException catch (_) {
    } catch (_) {}
  }

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
