class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String createdAt;
  final String lastActiveDate;
  final bool onboardingComplete;
  final String aslLevel;
  final int dailyGoalMinutes;
  final bool notificationsEnabled;
  final String startLessonId;
  final int currentStreak;
  final int longestStreak;
  final String lastStreakDate;
  final int totalXp;
  final bool ttsEnabled;
  final bool soundEnabled;
  final bool isAnonymous;
  final String authProvider;
  final int streakGoalDays;
  final String streakGoalStartDate;
  final bool streakGoalAchieved;
  final Map<String, double> signAccuracy;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.lastActiveDate,
    required this.onboardingComplete,
    required this.aslLevel,
    required this.dailyGoalMinutes,
    required this.notificationsEnabled,
    required this.startLessonId,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastStreakDate,
    required this.totalXp,
    required this.ttsEnabled,
    required this.soundEnabled,
    required this.isAnonymous,
    required this.authProvider,
    required this.streakGoalDays,
    required this.streakGoalStartDate,
    required this.streakGoalAchieved,
    this.signAccuracy = const {},
  });

  UserModel copyWith({
    String? email,
    String? displayName,
    String? lastActiveDate,
    bool? onboardingComplete,
    String? aslLevel,
    int? dailyGoalMinutes,
    bool? notificationsEnabled,
    String? startLessonId,
    int? currentStreak,
    int? longestStreak,
    String? lastStreakDate,
    int? totalXp,
    bool? ttsEnabled,
    bool? soundEnabled,
    bool? isAnonymous,
    String? authProvider,
    int? streakGoalDays,
    String? streakGoalStartDate,
    bool? streakGoalAchieved,
    Map<String, double>? signAccuracy,
  }) =>
      UserModel(
        uid: uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        createdAt: createdAt,
        lastActiveDate: lastActiveDate ?? this.lastActiveDate,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        aslLevel: aslLevel ?? this.aslLevel,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        startLessonId: startLessonId ?? this.startLessonId,
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        lastStreakDate: lastStreakDate ?? this.lastStreakDate,
        totalXp: totalXp ?? this.totalXp,
        ttsEnabled: ttsEnabled ?? this.ttsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        isAnonymous: isAnonymous ?? this.isAnonymous,
        authProvider: authProvider ?? this.authProvider,
        streakGoalDays: streakGoalDays ?? this.streakGoalDays,
        streakGoalStartDate: streakGoalStartDate ?? this.streakGoalStartDate,
        streakGoalAchieved: streakGoalAchieved ?? this.streakGoalAchieved,
        signAccuracy: signAccuracy ?? this.signAccuracy,
      );

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) => UserModel(
        uid: uid,
        email: map['email'] as String? ?? '',
        displayName: map['displayName'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
        lastActiveDate: map['lastActiveDate'] as String? ?? '',
        onboardingComplete: map['onboardingComplete'] as bool? ?? false,
        aslLevel: map['aslLevel'] as String? ?? '',
        dailyGoalMinutes: (map['dailyGoalMinutes'] as num?)?.toInt() ?? 5,
        notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
        startLessonId: map['startLessonId'] as String? ?? 's1l1',
        currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
        lastStreakDate: map['lastStreakDate'] as String? ?? '',
        totalXp: (map['totalXp'] as num?)?.toInt() ?? 0,
        ttsEnabled: map['ttsEnabled'] as bool? ?? true,
        soundEnabled: map['soundEnabled'] as bool? ?? true,
        isAnonymous: map['isAnonymous'] as bool? ?? true,
        authProvider: map['authProvider'] as String? ?? 'anonymous',
        streakGoalDays: (map['streakGoalDays'] as num?)?.toInt() ?? 7,
        streakGoalStartDate: map['streakGoalStartDate'] as String? ?? '',
        streakGoalAchieved: map['streakGoalAchieved'] as bool? ?? false,
        signAccuracy: (map['signAccuracy'] as Map? ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toDouble())),
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'displayName': displayName,
        'createdAt': createdAt,
        'lastActiveDate': lastActiveDate,
        'onboardingComplete': onboardingComplete,
        'aslLevel': aslLevel,
        'dailyGoalMinutes': dailyGoalMinutes,
        'notificationsEnabled': notificationsEnabled,
        'startLessonId': startLessonId,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastStreakDate': lastStreakDate,
        'totalXp': totalXp,
        'ttsEnabled': ttsEnabled,
        'soundEnabled': soundEnabled,
        'isAnonymous': isAnonymous,
        'authProvider': authProvider,
        'streakGoalDays': streakGoalDays,
        'streakGoalStartDate': streakGoalStartDate,
        'streakGoalAchieved': streakGoalAchieved,
        'signAccuracy': signAccuracy,
      };
}
