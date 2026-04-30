# ARCHITECTURE.md — Code Structure & Patterns
# HiASL

This document defines the rules Claude must follow when generating any code for HiASL.
Consistency across all features is non-negotiable — every file must fit this structure.

---
## Design System

HiASL uses a soft pastel design language inspired by Bondee — 
friendly, clean, and approachable. Claude must follow these tokens 
for every screen and widget generated.

### Colour Palette
```dart
// lib/core/constants/app_colors.dart
class AppColors {
  // Backgrounds
  static const backgroundPrimary = Color(0xFFF0F4FF);   // soft lavender-white
  static const backgroundCard    = Color(0xFFFFFFFF);   // pure white cards
  static const backgroundAccent  = Color(0xFFE8F4FD);   // light sky blue

  // Brand
  static const primary    = Color(0xFF5B8DEF);   // Bondee-style medium blue
  static const primarySoft= Color(0xFFD6E6FF);   // pale blue (selected state)
  static const secondary  = Color(0xFF7CC8A4);   // soft mint green

  // Text
  static const textPrimary   = Color(0xFF1A1A2E); // near-black
  static const textSecondary = Color(0xFF8A8A9A); // medium grey
  static const textOnDark    = Color(0xFFFFFFFF); // white on coloured bg

  // Feedback
  static const success = Color(0xFF58CC02);  // green (correct)
  static const error   = Color(0xFFFF4B4B);  // red (incorrect)
  static const warning = Color(0xFFFFB347);  // amber (streak/XP)
  static const xpGold  = Color(0xFFFFD700);  // gold (XP counter)

  // Onboarding screens
  static const onboardingBg = Color(0xFF1A1A2E); // dark navy (welcome screens only)
}
```

### Typography
```dart
// Always use these — never inline TextStyle
// Heading large:  fontSize 28, fontWeight 800, color textPrimary
// Heading medium: fontSize 22, fontWeight 700, color textPrimary
// Body:           fontSize 16, fontWeight 400, color textSecondary
// Button text:    fontSize 16, fontWeight 700, color white or primary
// Caption:        fontSize 13, fontWeight 400, color textSecondary
// Font family: system default (no custom font needed)
```

### Card Style
```dart
// All cards use this decoration:
BoxDecoration(
  color: AppColors.backgroundCard,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: Offset(0, 4),
    )
  ],
)
```

### Button Style
```dart
// Primary button (full width):
BorderRadius.circular(14)
height: 54
color: AppColors.primary
// Disabled state: AppColors.primarySoft with textSecondary text

// Secondary/outline button:
BorderRadius.circular(14)
border: Border.all(color: AppColors.primary, width: 1.5)
color: transparent
```

### Spacing
```dart
// Page padding: 24px horizontal
// Card padding: 20px all sides
// Gap between elements: 12px / 16px / 24px (small/medium/large)
// Bottom safe area: always respect SafeArea
```

### General Rules
- Backgrounds are LIGHT (soft pastel) — not dark, except welcome/onboarding screens
- Cards always WHITE with soft shadow — never flat coloured backgrounds
- Buttons always FULL WIDTH at bottom of screen
- Icons: use rounded/friendly style (Material Rounded or similar)
- No harsh borders — use shadows and rounded corners instead
- Bottom navigation bar: white bg, selected item uses primary colour dot/pill
- Mascot images always centred with adequate whitespace around them

## Folder Structure

```
lib/
├── main.dart                        # App entry, Firebase init, Riverpod scope, router
├── router.dart                      # All go_router routes in one place
│
├── core/                            # App-wide infrastructure — never feature-specific
│   ├── constants/
│   │   ├── xp_constants.dart        # kXpLearnCorrect, kXpPracticeEasy, etc.
│   │   ├── difficulty_constants.dart # kDifficultySeconds
│   │   └── route_constants.dart     # route name string constants
│   ├── errors/
│   │   └── app_exception.dart       # Typed exceptions (AuthException, FirestoreException…)
│   ├── extensions/
│   │   └── string_extensions.dart   # e.g. String.toTitleCase()
│   └── utils/
│       ├── date_utils.dart          # ISO date helpers, streak date comparisons
│       └── duration_formatter.dart  # Format int seconds → "3 min 24 sec"
│
├── data/                            # Static local data — no Firestore, no state
│   ├── lesson_definitions.dart      # kLessons, kSections (const lists)
│   ├── sign_finger_states.dart      # kSignFingerStates map
│   ├── sign_label_map.dart          # kSignLabels index→label list
│   └── quest_pool.dart              # kQuestPool const list
│
├── models/                          # Pure Dart data classes — no logic, no Flutter imports
│   ├── user_model.dart
│   ├── lesson_model.dart
│   ├── practice_result_model.dart
│   ├── daily_quest_model.dart
│   ├── quest_model.dart
│   ├── recognition_result.dart
│   ├── checkout_data.dart
│   └── section_definition.dart
│
├── services/                        # External integrations — one responsibility each
│   ├── auth_service.dart            # Firebase Auth wrapper
│   ├── firestore_service.dart       # ALL Firestore reads/writes — only file that imports cloud_firestore
│   ├── tts_service.dart             # flutter_tts wrapper
│   ├── sound_service.dart           # audioplayers wrapper
│   └── notification_service.dart    # flutter_local_notifications wrapper
│
├── providers/                       # Riverpod providers — state only, thin logic
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   ├── lesson_provider.dart
│   ├── streak_provider.dart
│   ├── xp_provider.dart
│   ├── quest_provider.dart
│   └── settings_provider.dart
│
├── controllers/                     # Session-scoped business logic — ephemeral
│   ├── learn_session_controller.dart
│   ├── practice_session_controller.dart
│   ├── onboarding_controller.dart
│   ├── recognition_controller.dart
│   └── placement_test_controller.dart
│
├── screens/                         # One folder per screen
│   ├── splash/
│   │   └── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── onboarding/
│   │   ├── onboarding_level_screen.dart       # S-04
│   │   ├── onboarding_goal_screen.dart        # S-05
│   │   ├── onboarding_notifications_screen.dart # S-06
│   │   ├── onboarding_start_screen.dart       # S-07
│   │   └── placement_test_screen.dart         # S-08
│   ├── home/
│   │   ├── home_screen.dart                   # S-09
│   │   └── widgets/
│   │       ├── section_card.dart
│   │       ├── lesson_card.dart
│   │       └── quest_strip.dart
│   ├── streak/
│   │   └── streak_screen.dart                 # S-10
│   ├── mode_select/
│   │   └── mode_select_screen.dart            # S-11
│   ├── learn/
│   │   ├── learn_screen.dart                  # S-12
│   │   └── widgets/
│   │       ├── hand_model_viewer.dart
│   │       ├── camera_preview_widget.dart
│   │       └── finger_guidance_overlay.dart
│   ├── practice/
│   │   ├── practice_setup_screen.dart         # S-13
│   │   ├── practice_session_screen.dart       # S-14
│   │   └── widgets/
│   │       ├── countdown_timer_bar.dart
│   │       └── sign_prompt_card.dart
│   ├── checkout/
│   │   ├── checkout_screen.dart               # S-15
│   │   └── widgets/
│   │       ├── xp_counter_animation.dart
│   │       └── quest_progress_row.dart
│   ├── completion/
│   │   └── learn_completion_screen.dart       # S-16
│   └── settings/
│       └── settings_screen.dart               # S-17
│
└── widgets/                         # Shared reusable widgets — used by 2+ screens
    ├── app_button.dart
    ├── inline_error_text.dart
    ├── progress_step_indicator.dart
    └── loading_overlay.dart
```

---

## Layer Dependency Rules

```
screens     →  providers, controllers, services (via ref only)
providers   →  services
controllers →  services (never providers)
services    →  Firebase SDK / flutter_tts / audioplayers / notifications
models      →  nothing (pure Dart)
data/       →  nothing (pure constants)
core/       →  nothing (pure utilities)
```

### Hard violations — Claude must never do these:
- ❌ `FirebaseFirestore.instance` outside `firestore_service.dart`
- ❌ `cloud_firestore` imported in any file other than `firestore_service.dart`
- ❌ Business logic inside `build()` or any widget method
- ❌ `TtsService.speak()` or `SoundService.play*()` called from a provider
- ❌ `context.go()` / `Navigator` called inside a provider or service
- ❌ Hardcoded XP values — always import from `core/constants/xp_constants.dart`
- ❌ Hardcoded route strings — always use `core/constants/route_constants.dart`
- ❌ Any provider file exceeding ~150 lines — split first

---

## Models

All models must:
- Have **only `final` fields** (immutable)
- Implement `copyWith()`, `fromMap(Map<String, dynamic>)`, `toMap()`
- Have `const` constructor where all fields are required
- Import nothing from `package:flutter`

```dart
// CORRECT model pattern
class LessonModel {
  final String lessonId;
  final int sectionNumber;
  final String status; // "locked" | "available" | "completed"
  final int practiceCount;
  final double bestAccuracy;

  const LessonModel({
    required this.lessonId,
    required this.sectionNumber,
    required this.status,
    required this.practiceCount,
    required this.bestAccuracy,
  });

  LessonModel copyWith({String? status, int? practiceCount, double? bestAccuracy}) =>
      LessonModel(
        lessonId: lessonId,
        sectionNumber: sectionNumber,
        status: status ?? this.status,
        practiceCount: practiceCount ?? this.practiceCount,
        bestAccuracy: bestAccuracy ?? this.bestAccuracy,
      );

  factory LessonModel.fromMap(Map<String, dynamic> map) => LessonModel(
        lessonId: map['lessonId'] as String,
        sectionNumber: map['sectionNumber'] as int,
        status: map['status'] as String,
        practiceCount: (map['practiceCount'] as num).toInt(),
        bestAccuracy: (map['bestAccuracy'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'lessonId': lessonId,
        'sectionNumber': sectionNumber,
        'status': status,
        'practiceCount': practiceCount,
        'bestAccuracy': bestAccuracy,
      };
}
```

---

## Services

- Registered as Riverpod `Provider` (not StateNotifier — services are stateless)
- All Firestore operations in `FirestoreService` only
- Throw `AppException` subtypes — never re-throw raw Firebase exceptions
- Each method has a single responsibility — no multi-step logic chains inside one method

```dart
// CORRECT service pattern
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updateLessonStatus(
      String uid, String lessonId, String status) async {
    try {
      await _db
          .collection('users').doc(uid)
          .collection('lessons').doc(lessonId)
          .update({'status': status, 'completedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      throw FirestoreException(e.message ?? 'Firestore write failed');
    }
  }

  Stream<List<LessonModel>> watchLessons(String uid) =>
      _db.collection('users').doc(uid).collection('lessons').snapshots().map(
            (snap) => snap.docs.map((d) => LessonModel.fromMap(d.data())).toList(),
          );
}

// Provider registration
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
```

---

## Providers

- `StreamProvider` → Firestore live data
- `FutureProvider` → one-time reads
- `StateNotifierProvider` → mutable state with methods
- Providers read only from services, never from `FirebaseFirestore.instance`
- Providers expose typed models, never raw `Map<String, dynamic>`

```dart
// StreamProvider example
final lessonProvider = StreamProvider.family<List<LessonModel>, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).watchLessons(uid);
});

// StateNotifier example
class XpNotifier extends StateNotifier<int> {
  XpNotifier(this._service, this._uid) : super(0);
  final FirestoreService _service;
  final String _uid;

  Future<void> award(int amount) async {
    await _service.incrementXp(_uid, amount);
    state = state + amount;
  }
}

final xpProvider = StateNotifierProvider<XpNotifier, int>((ref) {
  final uid = ref.watch(authProvider).value!.uid;
  return XpNotifier(ref.read(firestoreServiceProvider), uid);
});
```

---

## Controllers

- Created per-session (ephemeral) — scoped to the screen, disposed on exit
- Extend `StateNotifier<T>` with a typed state class
- Orchestrate services — call `soundService`, `ttsService`, update local state
- Do **not** write to Firestore — that happens in the checkout screen after the session
- Expose a `buildCheckoutData()` method to produce `CheckoutData` for the checkout screen

```dart
// CORRECT controller pattern
class LearnSessionController extends StateNotifier<LearnSessionState> {
  LearnSessionController({
    required this.lesson,
    required this.soundService,
    required this.ttsService,
  }) : super(LearnSessionState.initial(lesson));

  final LessonDefinition lesson;
  final SoundService soundService;
  final TtsService ttsService;

  void startSession(RecognitionController recognition) {
    recognition.startSession();
    ttsService.speak(state.currentSign);
  }

  void onCorrect() {
    soundService.playSuccess();
    ttsService.speak('Correct!');
    state = state.advance(); // immutable state update
  }

  void onIncorrect(String guidanceText) {
    soundService.playError();
    ttsService.speak(guidanceText);
    state = state.withGuidance(guidanceText);
  }

  CheckoutData buildCheckoutData() => CheckoutData(
        xpEarned: state.xpEarned,
        accuracyPercent: state.accuracy,
        durationSeconds: state.elapsedSeconds,
        sessionType: 'learn',
        lessonId: lesson.id,
        streakExtended: false,
      );

  @override
  void dispose() {
    // recognition.stopSession() called here via the screen's dispose()
    super.dispose();
  }
}
```

---

## Screens

- **Thin** — observe state, dispatch events, render UI. Zero logic.
- Use `ConsumerStatefulWidget` when lifecycle methods needed (initState, dispose)
- Use `ConsumerWidget` for stateless screens
- Always call `controller.dispose()` / `stopSession()` in `dispose()`
- All UI strings as `const` at file top or in a dedicated strings map — no inline hardcoding
- Use `ThemeData` text styles — no inline `TextStyle(fontSize: 18, color: Colors.red)`
- Handle all three async states: `data`, `loading`, `error`

```dart
// CORRECT screen pattern
class LearnScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const LearnScreen({required this.lessonId, super.key});
  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  late final LearnSessionController _controller;

  @override
  void initState() {
    super.initState();
    final lesson = kLessons.firstWhere((l) => l.id == widget.lessonId);
    _controller = LearnSessionController(
      lesson: lesson,
      soundService: ref.read(soundServiceProvider),
      ttsService: ref.read(ttsServiceProvider),
    );
    _controller.startSession(ref.read(recognitionControllerProvider));
  }

  @override
  void dispose() {
    ref.read(recognitionControllerProvider).stopSession();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // pure UI — read state, render widgets, call _controller methods on events
  }
}
```

---

## Widgets

- Goes in `screens/{feature}/widgets/` if used by one screen only
- Goes in `lib/widgets/` only if used by 2+ screens
- Accept only the data they need via constructor — no `ref.watch` in leaf widgets
- `const` constructors wherever possible
- No business logic — only rendering and forwarding callbacks

---

## Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Files | `snake_case.dart` | `learn_session_controller.dart` |
| Classes | `PascalCase` | `LearnSessionController` |
| Providers | `camelCaseProvider` | `lessonProvider`, `xpProvider` |
| Constants | `kCamelCase` | `kXpLearnCorrect`, `kLessons` |
| Routes (path) | `/kebab-case/:param` | `/lesson/:lessonId/learn` |
| Route name constants | `kRoute + Feature` | `kRouteLearn` |
| Firestore collections | `camelCase` | `users`, `lessons`, `practiceResults` |
| Firestore field names | `camelCase` | `lessonId`, `totalXp`, `lastStreakDate` |
| Enums | `PascalCase` values | `LessonStatus.locked` |
| State classes | `PascalCase + State` | `LearnSessionState`, `PracticeSessionState` |

---

## Scalability Patterns

### Add a new Lesson or Section
1. Append to `kLessons` / `kSections` in `data/lesson_definitions.dart`
2. Nothing else changes — `initLessons()` and `LessonProvider` are data-driven

### Add a new Quest Type
1. Append to `kQuestPool` in `data/quest_pool.dart`
2. Add a `case` handler in `QuestNotifier.onSessionComplete()`
3. No schema or UI changes needed

### Add a new Screen
1. Create `screens/{feature}/{feature}_screen.dart`
2. Add route to `router.dart` + `core/constants/route_constants.dart`
3. Create controller in `controllers/` if session logic needed
4. Never modify unrelated existing files

### Add a new Setting
1. Add field to `UserModel` + `FirestoreService.updateSetting()`
2. Add toggle to `settings_screen.dart`
3. Read via `settingsProvider` in the relevant service

### Swap a service implementation (e.g. change TTS library)
1. New class implements the same abstract interface
2. Re-register in the Riverpod provider
3. Zero changes to screens, controllers, or other services

---

## Error Handling

- Services always wrap Firebase calls in `try/catch`, throw `AppException` subtypes
- Providers expose `AsyncValue<T>` — screens handle `.when(data, loading, error)`
- Never use `!` on nullable Firestore values — always provide a default
- Controller methods catch exceptions and update state to an error variant

```dart
// CORRECT async handling in screen
final lessonsAsync = ref.watch(lessonProvider(uid));
return lessonsAsync.when(
  data:    (lessons) => LessonList(lessons: lessons),
  loading: () => const LoadingOverlay(),
  error:   (e, _)  => const Center(child: Text('Something went wrong. Try again.')),
);
```

---

## File Length Limits

| Type | Soft limit |
|---|---|
| Screen | 200 lines |
| Controller | 150 lines |
| Provider | 100 lines |
| Service | 200 lines |
| Model | 80 lines |
| Widget | 100 lines |

If a file approaches its limit → split into smaller focused units before adding more code.
