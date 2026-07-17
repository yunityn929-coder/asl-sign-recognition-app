# PROMPTS.md — Claude Session Starters
# HiASL

Paste the relevant block at the start of each Claude session.
Build features in order — later features depend on earlier ones.

---

## BASE CONTEXT (paste this at the start of EVERY session)
```
I'm building HiASL — a Flutter/Dart Android ASL learning app.
Docs are in /docs:
  ARCHITECTURE.md  — folder structure, layering rules, patterns, naming conventions
  SRS.md           — all requirements + curriculum
  TECH_STACK.md    — packages and integration details
  DATA_SCHEMA.md   — Firestore schema + all local constants
  APP_FLOW.md      — every screen spec + navigation + service interfaces

Rules (always follow ARCHITECTURE.md):
- No Firestore access outside firestore_service.dart
- No business logic in build() or widgets
- No hardcoded XP values or route strings — use core/constants/
- Providers call services only; controllers call services only
- Models are immutable with copyWith/fromMap/toMap
- Screens are thin — observe state, dispatch events, render
- File length limits: screen 200, controller 150, provider 100, service 200, model 80 lines
- Split any file approaching its limit before adding more code

Stack: Flutter + Dart, Android 10+, Firebase Auth + Firestore, Riverpod, go_router.
Audio: flutter_tts (TTS), audioplayers (sound effects). No custom backend.
On-device inference: MediaPipe Hands + TFLite. Camera data never leaves device.
Design: Bondee-inspired soft pastel UI. All colours and styles from AppColors in ARCHITECTURE.md. Never hardcode colours.
```

---

## FEATURE PROMPTS (build in this order)

### 1. Project Setup
```
Task: Set up the HiASL Flutter project skeleton.
Follow ARCHITECTURE.md folder structure exactly.

- pubspec.yaml with all packages from TECH_STACK.md
- Full folder structure from ARCHITECTURE.md (all dirs, even if empty — add .gitkeep)
- core/constants/: xp_constants.dart, difficulty_constants.dart, route_constants.dart
- core/errors/app_exception.dart: base AppException + AuthException, FirestoreException subtypes
- router.dart: all routes from APP_FLOW.md screen inventory (S-01 to S-17) using go_router
- main.dart: Firebase init, ProviderScope, router, SoundService + TtsService init
- S-01 Splash: check FirebaseAuth.currentUser + onboardingComplete → route to /onboarding/level or /home
- assets/ structure from TECH_STACK.md registered in pubspec.yaml

Output: compiles, shows splash, routes correctly to login or onboarding/level.
```

### 2. Silent Auth + UserModel + FirestoreService
```
Task: Build silent anonymous auth, AuthService, UserModel, FirestoreService base.
Follow ARCHITECTURE.md: all auth/Firestore in services, never in screens.

Spec: APP_FLOW.md S-01. DATA_SCHEMA.md users/{uid} + all amendment sections.
TECH_STACK.md auth amendment section. No login screen needed.

auth_service.dart:
  signInSilently(): FirebaseAuth.signInAnonymously() — called on S-01, no UI
  linkWithGoogle(): currentUser.linkWithCredential(GoogleAuthProvider.credential)
    — only called from S-25 (leaderboard social unlock)
  get isAnonymous: FirebaseAuth.currentUser?.isAnonymous ?? true

FirestoreService.createUser(uid):
  Write ALL fields from DATA_SCHEMA.md users/{uid} with defaults:
  displayName:"Learner", isAnonymous:true, authProvider:"anonymous",
  onboardingComplete:false, ttsEnabled:true, soundEnabled:true,
  totalXp:0, currentStreak:0, longestStreak:0, streakGoalDays:7,
  streakGoalAchieved:false, notificationsEnabled:false
  Only write if doc does not already exist

FirestoreService.updateUser(uid, Map fields): partial Firestore update

UserModel: ALL fields from DATA_SCHEMA.md + amendments. fromMap/toMap/copyWith.

S-01 Splash:
  1. Show logo ~1.5s
  2. AuthService.signInSilently()
  3. If no Firestore doc → FirestoreService.createUser(uid)
  4. Read onboardingComplete
  5. Route: false → /welcome/brand | true → /home
```

### 2b. Welcome Screens + Full Onboarding (S-02 to S-12)
```
UI must follow the design system in ARCHITECTURE.md — 
soft pastel backgrounds, white cards, Bondee-inspired aesthetic.
Welcome/onboarding screens use dark navy background (AppColors.onboardingBg).
Home and all post-onboarding screens use light pastel background (AppColors.backgroundPrimary).

Task: Build welcome screens (S-02, S-03, S-04) and onboarding flow (S-05 to S-12).
Follow ARCHITECTURE.md: OnboardingController holds answers, screens are thin.

Spec: APP_FLOW.md S-02 through S-12 — read EACH screen spec carefully.
DATA_SCHEMA.md onboarding fields + streakGoalDays + kStreakGoalXp + amendment section.

OnboardingController (StateNotifier<OnboardingState>):
  Fields: aslLevel, dailyGoalMinutes, notificationsEnabled, startingPoint, streakGoalDays
  complete(startLessonId): batch write all fields + onboardingComplete:true +
    streakGoalStartDate:today to Firestore via FirestoreService.updateUser()

Build screens in this order (each calls TTS on entry for speech bubble text):

S-02: Full screen dark bg. mascot_wave.png centre. "GET STARTED" → S-03.
      Small link "I already have an account" → S-25.

S-03: mascot_speech.png. Speech bubble: "Hi there! I am Hani!" CONTINUE → S-04.

S-04: mascot_excited.png. Speech bubble: "Just 4 quick questions before we start!"
      CONTINUE → S-05.

S-05: Progress 1/4. Small mascot top-left + speech bubble "How much ASL do you know?"
      4 radio cards with signal-bar icon. CONTINUE (disabled until selected) → S-06.

S-06: Progress 2/4. Speech bubble "What is your daily learning goal?"
      4 cards: 5/10/15/20 min with Casual/Regular/Serious/Intense labels.
      Button: "I'M COMMITTED" (disabled until selected) → S-07.

S-07: Progress 3/4. Speech bubble "I will remind you to practice so it becomes a habit!"
      Button: "REMIND ME TO PRACTICE" → permission_handler POST_NOTIFICATIONS → S-08.
      Link: "Maybe later" → S-08 (notificationsEnabled: false).

S-08: Progress 4/4. Speech bubble "Here is what you can achieve!"
      3 feature rows: 🤟 Sign with confidence / ⚡ Build vocabulary / 🔥 Develop habit.
      CONTINUE → S-09.

S-09: 2 large option cards. "Start from scratch" always shown.
      "Find my level" with RECOMMENDED badge — hidden if aslLevel == "none".
      CONTINUE → scratch: initLessons() → S-12 | level: S-10.

S-10: Placement test. 10 items. Hard (5s). No skip. No TTS. No XP. No checkout.
      Complete → S-11.

S-11: Celebration screen. Coloured background. mascot_celebrate.png animated.
      "Since you [aslLevel answer], start with [SectionName]!"
      "LET'S GO" → initLessons(startLessonId) → S-12.

S-12: Streak goal. mascot_commit.png + flame icon.
      4 cards: 7/14/30/50 days with XP rewards from kStreakGoalXp in DATA_SCHEMA.md.
      "COMMIT TO MY GOAL" → OnboardingController.complete(startLessonId) → S-13.

Shared requirements for ALL onboarding screens:
  - Dark background
  - TTS reads speech bubble text on screen entry
  - Back arrow to previous screen
  - No skip except S-07 notification screen
```

### 3. Onboarding Flow (S-04 → S-07)
```
Task: Build the 4-screen onboarding flow.
Follow ARCHITECTURE.md: OnboardingController handles logic, screens are thin.

Spec: APP_FLOW.md S-04, S-05, S-06, S-07. DATA_SCHEMA.md onboarding fields.

- OnboardingController: holds answers in memory, writes batch to Firestore on completion
- TtsService.speak() called in initState of each screen (on screen entry)
- progress_step_indicator.dart widget (shared, steps 1–4)
- S-04: 4 radio option cards → store aslLevel
- S-05: 3 goal cards → store dailyGoalMinutes
- S-06: explain notifications → permission_handler → store notificationsEnabled
  If granted → NotificationService.scheduleReminder()
- S-07: "Start from scratch" (always visible) | "Find my level" (hidden if aslLevel=="none")
  "Start from scratch" → OnboardingController.complete() → initLessons() → navigate /home
  "Find my level" → navigate /onboarding/placement
All onboarding fields written in a single Firestore batch write on completion.
```

### 4. Lesson Initialisation & LessonProvider
```
Task: Build initLessons(), LessonProvider, and Home screen (S-09).
Follow ARCHITECTURE.md: FirestoreService handles all writes, LessonProvider streams data.

Spec: DATA_SCHEMA.md lesson gating rules + kLessons + kSections. APP_FLOW.md S-09.

- data/lesson_definitions.dart: kLessons and kSections const lists (full list from DATA_SCHEMA.md)
- FirestoreService.initLessons(uid, startLessonId):
  Write all lesson docs; lessons before startLessonId → status:"completed"
  startLessonId → status:"available"; rest → status:"locked"
- FirestoreService.unlockNextLesson(uid, completedLessonId):
  Next lesson in same section → "available"
  If last in section → first lesson of next section → "available"
- lesson_provider.dart: StreamProvider streaming users/{uid}/lessons/
- Home screen (S-09):
  App bar: "HiASL" + XP counter + streak flame icon + settings icon
  Quest strip (horizontal scroll, 3 cards) — use QuestProvider (stub if not built yet)
  Section list (collapsible): kSections headers, lesson cards from LessonProvider
  Lesson card states: locked (grey + 🔒) | available | completed (+ ✓)
  TTS reads lesson title on card tap before navigating
```

### 5. Placement Test (S-08)
```
Task: Build Placement Test screen (S-08) and PlacementTestController.
Follow ARCHITECTURE.md: controller holds session logic, screen is thin.

Spec: APP_FLOW.md S-08. SRS.md Placement Test behaviour.
DATA_SCHEMA.md kLessons — determine entry section from aslLevel.

- PlacementTestController extends StateNotifier<PlacementTestState>:
  10 random signs from entry section, Hard difficulty (5s), no skip
  No TTS prompts (test conditions)
  onCorrect(), onTimeout(), buildResult() → PlacementTestResult
- S-08 screen: no back button, must complete
  On complete: show score briefly ("You scored X/10")
  Determine startLessonId from score (≥8 → advance, <8 → Q1 start)
  Call FirestoreService.initLessons() → write onboardingComplete:true → navigate /home
- No XP awarded; no checkout screen shown
```

### 6. TTS Service & Sound Service
```
Task: Implement TtsService and SoundService as singletons.
Follow ARCHITECTURE.md: services are stateless, registered as Riverpod providers.

Spec: APP_FLOW.md TtsService and SoundService interfaces. TECH_STACK.md audio section.

- services/tts_service.dart (flutter_tts):
  speak(String text): stop() then speak asynchronously — never await in callers
  stop(): cancel current speech
  enabled: bool — read from settingsProvider (or passed in)
  Riverpod provider: ttsServiceProvider
- services/sound_service.dart (audioplayers):
  Preload all 4 audio files on init: success.mp3, error.mp3, fanfare.mp3, xp_gain.mp3
  playSuccess(), playError(), playFanfare(), playXpGain() — all fire-and-forget
  enabled: bool — read from settingsProvider
  Riverpod provider: soundServiceProvider
- Both services must not block UI — all audio calls are async, never awaited at call sites
```

### 7. Gesture Recognition Controller
```
Task: Build RecognitionController.
Follow ARCHITECTURE.md: service-level class, registered as Riverpod provider.

Spec: APP_FLOW.md RecognitionController interface. TECH_STACK.md gesture recognition section.
DATA_SCHEMA.md kSignFingerStates and kSignLabels.

- RecognitionController:
  Camera feed → MediaPipe Hands (platform channel) → 21 landmarks → 63 floats
  Normalise: subtract wrist (landmark index 0), divide by norm of landmark 9
  Feed [1,63] tensor into mlp_model.tflite via tflite_flutter
  Emit Stream<RecognitionResult> — see APP_FLOW.md for RecognitionResult fields
  Confidence < 0.85 → emit with handDetected:true but label empty (triggers FR-17 hint)
  startSession() → activate camera
  stopSession() → dispose camera
  Never start/stop per attempt — runs continuously for the session lifetime
- FingerStateChecker utility (in controllers/ or core/utils/):
  checkFingerStates(List<double> landmarks, String targetSign) → String? guidanceMessage
  Returns first mismatching finger message or null if all match
  Uses kSignFingerStates from data/sign_finger_states.dart
```

### 8. Learn Session Screen (S-12)
```
Task: Build Learn Session screen (S-12) and LearnSessionController.
Follow ARCHITECTURE.md: controller holds all logic, screen only renders and dispatches.

Spec: APP_FLOW.md S-12. SRS.md Learn Mode behaviour.
FR-05,FR-06,FR-08,FR-09,FR-10,FR-14,FR-17,FR-28,FR-30,FR-33,FR-34,FR-45.

- LearnSessionState: current sign index, xpEarned, guidanceText, sessionStatus, elapsedSeconds
- LearnSessionController: onCorrect(), onIncorrect(landmarks), onLowDetection(), buildCheckoutData()
  onCorrect: soundService.playSuccess() + ttsService.speak("Correct!") + award kXpLearnCorrect
  onIncorrect: soundService.playError() + FingerStateChecker → ttsService.speak(guidanceText)
  onLowDetection: update state only (no sound, no TTS)
- S-12 screen layout: progress bar | 3D model (flutter_3d_controller, rotate/zoom) |
  sign label text (TTS on each sign load) | camera preview | feedback overlay
- State machine from APP_FLOW.md S-12
- On session end: navigate to /session/checkout passing CheckoutData
- dispose(): recognitionController.stopSession() + controller.dispose()
- widgets/hand_model_viewer.dart: wraps flutter_3d_controller, takes sign label → loads sign_{label}.glb
- widgets/finger_guidance_overlay.dart: shows guidance text with animation
```

### 9. Practice Setup & Session (S-13, S-14)
```
Task: Build Practice Setup (S-13) and Practice Session (S-14) with PracticeSessionController.
Follow ARCHITECTURE.md: controller holds session logic, screen is thin.

Spec: APP_FLOW.md S-13, S-14. SRS.md Practice Mode behaviour.
FR-11,FR-12,FR-13,FR-15,FR-28,FR-30,FR-33,FR-34,FR-46. DATA_SCHEMA.md kDifficultySeconds.

- PracticeSessionState: items[], currentIndex, correctCount, xpEarned, elapsedSeconds
- PracticeSessionController:
  generateItems(lesson, difficulty): random signs, no duplicates
  startItem(): TtsService.speak(signLabel) + start timer
  onCorrect(): sound + TTS + award XP (kXpPracticeEasy/Medium/Hard) + advance
  onTimeout(): error sound + TTS "Time's up" + advance
  buildCheckoutData(): accuracy, xpEarned, duration, "practice", lessonId
- S-13: difficulty selector cards (Easy🐢/Medium⚡/Hard🔥, default Easy) → navigate S-14
- S-14: large text prompt "Sign: [LABEL]" (NO 3D model)
  countdown_timer_bar.dart widget, Skip button
  State machine from APP_FLOW.md S-14
  On end: navigate to /session/checkout passing CheckoutData
```

### 10. Session Checkout (S-15)
```
Task: Build Session Checkout screen (S-15).
Follow ARCHITECTURE.md: screen receives CheckoutData as nav arg, writes to Firestore via services.

Spec: APP_FLOW.md S-15. SRS.md Session Checkout behaviour. FR-38 to FR-44.
DATA_SCHEMA.md practiceResults schema + streak logic + XP constants.

On entry:
  SoundService.playFanfare()
  TtsService.speak("You earned {xpEarned} XP!")
  Write practiceResult doc to Firestore (FirestoreService.savePracticeResult())
  XpProvider.award(xpEarned) — also checks streak milestone bonus
  StreakProvider.updateStreak() — streak logic from DATA_SCHEMA.md
  QuestProvider.onSessionComplete(checkoutData) — update quest progress

UI:
  widgets/xp_counter_animation.dart: animated roll from 0 → xpEarned
  Accuracy % with colour indicator (green ≥80%, amber ≥60%, red <60%)
  Duration formatted via DurationFormatter.format(seconds)
  Streak row: "🔥 N day streak" + "Streak extended! ✓" if applicable
  widgets/quest_progress_row.dart: 3 quest bars; completed quest → badge + XP sound + TTS

Buttons:
  "Continue" → if sessionType=="learn" → /lesson/:id/complete else → /home
  "Try Again" (practice only) → /lesson/:id/practice/setup
```

### 11. XP System & Daily Quests
```
Task: Build XpProvider, QuestProvider, and QuestNotifier.
Follow ARCHITECTURE.md: providers call FirestoreService, never Firestore directly.

Spec: SRS.md FR-45 to FR-56. DATA_SCHEMA.md XP constants + dailyQuests schema + quest pool.
data/quest_pool.dart: kQuestPool const list.

XpProvider (StateNotifierProvider<XpNotifier, int>):
  Initialise from user doc totalXp
  award(int amount): FirestoreService.incrementXp() + state += amount
  checkStreakMilestone(int streak): if streak % 7 == 0 → award kXpStreakBonus

QuestProvider (StateNotifierProvider<QuestNotifier, List<QuestModel>>):
  On init: read dailyQuests/{today}; if not exists → generate 3 from kQuestPool → write
  onSessionComplete(CheckoutData): update progress for matching quest types:
    complete_lessons: +1 per any session
    earn_xp: +checkoutData.xpEarned
    practice_sessions: +1 per practice session
    correct_streak: track consecutive corrects — update if new max
  If progress >= target && !completed: mark completed → XpProvider.award(kXpQuestBonus)
  Quest strip on S-09: reactive to QuestProvider state
```

### 12. Streak, Notifications & Settings (S-10, S-17)
```
Task: Build StreakProvider, Streak screen (S-10), Settings screen (S-17), notifications.
Follow ARCHITECTURE.md: StreakProvider → FirestoreService; NotificationService is a standalone service.

Spec: APP_FLOW.md S-10, S-17. DATA_SCHEMA.md streak update logic. SRS.md FR-18, FR-57, FR-58.

StreakProvider (StateNotifierProvider<StreakNotifier, StreakState>):
  updateStreak(): implements DATA_SCHEMA.md streak logic exactly
  Returns bool streakExtended (used in CheckoutData)
  Calls XpProvider.award(kXpStreakBonus) on 7-day milestone via checkStreakMilestone

NotificationService (flutter_local_notifications + timezone):
  scheduleReminder(): daily at 19:00 local, title "Time to practice! 🤟"
  cancelIfPracticedToday(): check lastStreakDate == today → cancel pending notification
  Called from onboarding if permission granted; rescheduled from Settings

S-10 Streak screen:
  Large streak count + flame animation
  Longest streak
  30-day activity heatmap (coloured dots — green if practiced, grey if not)
  Message: 0 days → "Start your streak today!" | 1–6 → "Keep it up!" | 7+ → "You're on fire! 🔥"

S-17 Settings screen:
  TTS toggle → FirestoreService.updateUserField('ttsEnabled', value)
  Sound toggle → FirestoreService.updateUserField('soundEnabled', value)
  Reminder time picker → NotificationService.scheduleReminder(newTime)
  Display name text field → FirestoreService.updateUserField('displayName', value)
  Logout → AuthService.signOut() → navigate /login (clear stack)
```

### 13. Debugging / Bug Fix
```
I'm working on HiASL (Flutter/Dart). Docs in /docs — follow ARCHITECTURE.md rules.
Issue:
[PASTE ERROR OR DESCRIBE BUG]

Relevant files:
[PASTE FILE PATHS AND CODE]

Fix only what's broken. Do not rewrite files I haven't shared.
Ensure the fix does not violate ARCHITECTURE.md layering rules.
```

---

## TOKEN-SAVING TIPS
- Paste Base Context + ONE feature prompt per session
- Share only files relevant to the current feature
- Confirm each feature compiles and works before starting the next
- Build strictly in order 1→12
- Feature 7 (Recognition Controller) is highest risk — get it logging raw predictions to console before wiring to any UI
- If Claude generates code that puts Firestore calls in a screen or logic in a widget — stop, point it to ARCHITECTURE.md, ask it to refactor before continuing
