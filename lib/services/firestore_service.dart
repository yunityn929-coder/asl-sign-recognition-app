import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../data/lesson_definitions.dart';
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
      throw FirestoreException(e.message ?? 'Failed to update user');
    }
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

  String _today() => DateTime.now().toIso8601String().substring(0, 10);
}

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
