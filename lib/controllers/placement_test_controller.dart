import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlacementTestState {
  final List<String> signs;
  final int currentIndex;
  final int correctCount;
  final int timeLeftSeconds;
  final bool isComplete;

  const PlacementTestState({
    required this.signs,
    this.currentIndex = 0,
    this.correctCount = 0,
    this.timeLeftSeconds = 5,
    this.isComplete = false,
  });

  String get currentSign => currentIndex < signs.length ? signs[currentIndex] : '';
  int get totalSigns => signs.length;
  double get itemProgress => totalSigns == 0 ? 0 : (currentIndex + 1) / totalSigns;
  double get timeProgress => timeLeftSeconds / 5;

  PlacementTestState copyWith({
    int? currentIndex,
    int? correctCount,
    int? timeLeftSeconds,
    bool? isComplete,
  }) =>
      PlacementTestState(
        signs: signs,
        currentIndex: currentIndex ?? this.currentIndex,
        correctCount: correctCount ?? this.correctCount,
        timeLeftSeconds: timeLeftSeconds ?? this.timeLeftSeconds,
        isComplete: isComplete ?? this.isComplete,
      );
}

class PlacementTestController extends StateNotifier<PlacementTestState> {
  PlacementTestController(String aslLevel)
      : super(PlacementTestState(signs: _signsForLevel(aslLevel)));

  Timer? _timer;

  void start() => _startTimer();

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(timeLeftSeconds: 5);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.timeLeftSeconds > 1) {
        state = state.copyWith(timeLeftSeconds: state.timeLeftSeconds - 1);
      } else {
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    _timer?.cancel();
    _advance(correct: false);
  }

  void _advance({required bool correct}) {
    final newCorrect = state.correctCount + (correct ? 1 : 0);
    if (state.currentIndex >= state.signs.length - 1) {
      state = state.copyWith(correctCount: newCorrect, isComplete: true);
    } else {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        correctCount: newCorrect,
        timeLeftSeconds: 5,
      );
      _startTimer();
    }
  }

  // Maps correct count to the recommended start lesson.
  String startLessonId() {
    final score = state.correctCount;
    if (score >= 8) return 's3l1';
    if (score >= 5) return 's2l1';
    return 's1l1';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static List<String> _signsForLevel(String aslLevel) {
    final pool = switch (aslLevel) {
      'alphabet' || 'conversational' => <String>['K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T'],
      'some' => <String>['F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O'],
      _ => <String>['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'],
    };
    pool.shuffle();
    return pool;
  }
}

final placementTestControllerProvider = StateNotifierProvider.autoDispose
    .family<PlacementTestController, PlacementTestState, String>((ref, aslLevel) {
  return PlacementTestController(aslLevel);
});
