import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';

class OnboardingState {
  final String aslLevel;
  final Set<String> reasons;
  final int dailyGoalMinutes;
  final bool notificationsEnabled;
  final String startingPoint;
  final int streakGoalDays;

  const OnboardingState({
    this.aslLevel = '',
    this.reasons = const {},
    this.dailyGoalMinutes = 5,
    this.notificationsEnabled = false,
    this.startingPoint = 'scratch',
    this.streakGoalDays = 7,
  });

  OnboardingState copyWith({
    String? aslLevel,
    Set<String>? reasons,
    int? dailyGoalMinutes,
    bool? notificationsEnabled,
    String? startingPoint,
    int? streakGoalDays,
  }) =>
      OnboardingState(
        aslLevel: aslLevel ?? this.aslLevel,
        reasons: reasons ?? this.reasons,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        startingPoint: startingPoint ?? this.startingPoint,
        streakGoalDays: streakGoalDays ?? this.streakGoalDays,
      );
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._firestore, this._uid) : super(const OnboardingState());

  final FirestoreService _firestore;
  final String _uid;

  void setAslLevel(String level) => state = state.copyWith(aslLevel: level);
  void toggleReason(String key) {
    final updated = Set<String>.from(state.reasons);
    if (!updated.remove(key)) updated.add(key);
    state = state.copyWith(reasons: updated);
  }
  void setDailyGoal(int minutes) => state = state.copyWith(dailyGoalMinutes: minutes);
  void setNotifications(bool enabled) => state = state.copyWith(notificationsEnabled: enabled);
  void setStartingPoint(String point) => state = state.copyWith(startingPoint: point);
  void setStreakGoal(int days) => state = state.copyWith(streakGoalDays: days);

  Future<void> initLessons(String startLessonId) async {
    if (_uid.isEmpty) return;
    await _firestore.initLessons(_uid, startLessonId);
  }

  Future<void> complete(String startLessonId) async {
    if (_uid.isEmpty) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _firestore.updateUser(_uid, {
      'aslLevel': state.aslLevel,
      'reasons': state.reasons.toList(),
      'dailyGoalMinutes': state.dailyGoalMinutes,
      'notificationsEnabled': state.notificationsEnabled,
      'startLessonId': startLessonId,
      'streakGoalDays': state.streakGoalDays,
      'streakGoalStartDate': today,
      'onboardingComplete': true,
    });
  }
}

// Rebuilds (fresh state + fresh uid) whenever the signed-in uid actually
// changes — e.g. sign-out/delete-account followed by a new anonymous
// session — so answers from a previous account can never leak into, or get
// submitted under, the next one. select() keeps this from also rebuilding
// on same-uid token refreshes, which would otherwise wipe in-progress
// answers mid-onboarding.
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final uid = ref.watch(authStateProvider.select((async) => async.value?.uid)) ?? '';
  return OnboardingController(ref.read(firestoreServiceProvider), uid);
});
