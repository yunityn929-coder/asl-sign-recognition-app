# APP_FLOW.md — Screen Map & Navigation
# HiASL

## Screen Inventory

| ID | Name | Route |
|---|---|---|
| S-01 | Splash / Auth Gate | `/` |
| S-02 | Login / Sign-Up | `/login` |
| S-04 | Onboarding Q1: ASL Level | `/onboarding/level` |
| S-05 | Onboarding Q2: Daily Goal | `/onboarding/goal` |
| S-06 | Onboarding Q3: Notifications | `/onboarding/notifications` |
| S-07 | Onboarding Q4: Starting Point | `/onboarding/start` |
| S-08 | Placement Test | `/onboarding/placement` |
| S-09 | Home (Section + Lesson List) | `/home` |
| S-10 | Streak Page | `/streak` |
| S-11 | Mode Select | `/lesson/:lessonId/mode` |
| S-12 | Learn Session | `/lesson/:lessonId/learn` |
| S-13 | Practice Setup | `/lesson/:lessonId/practice/setup` |
| S-14 | Practice Session | `/lesson/:lessonId/practice/session` |
| S-15 | Session Checkout | `/session/checkout` |
| S-16 | Learn Completion | `/lesson/:lessonId/complete` |
| S-17 | Settings | `/settings` |
| S-18 | Convert Guest Account | `/account/convert` |

---

## Navigation Flow

```
[S-01 Splash]
  ├── not authenticated → [S-02 Login / Sign-Up]
  │     ├── "Continue with Google" → Google Sign-In
  │     │     ├── new Google user → create Firestore doc → [S-04 Onboarding Q1]
  │     │     └── returning Google user → check onboardingComplete → [S-04] or [S-09]
  │     ├── "Continue as Guest" → Firebase Anonymous Auth
  │     │     └── always → [S-04 Onboarding Q1]  (guests always onboard fresh)
  │     ├── "Log In" → email + password → check onboardingComplete → [S-04] or [S-09]
  │     └── "Sign Up" → email + displayName + password → [S-04 Onboarding Q1]
  └── authenticated:
        ├── onboardingComplete == false → [S-04 Onboarding Q1]
        └── onboardingComplete == true  → [S-09 Home]

[S-04] → [S-05] → [S-06] → [S-07]
  ├── "Start from scratch" → initialise lessons → [S-09 Home]
  └── "Find my level" + Q1 != "none" → [S-08 Placement Test]
        ├── score ≥ 8/10 → advance section → initialise lessons → [S-09 Home]
        └── score < 8/10 → Q1 start point → initialise lessons → [S-09 Home]

[S-09 Home]
  ├── streak icon → [S-10 Streak]
  ├── settings icon → [S-17 Settings]
  │     └── "Save Account" (guest only) → [S-18 Convert Guest]
  └── tap lesson → [S-11 Mode Select]
        ├── "Learn" → [S-12 Learn Session]
        │     └── ends → [S-15 Checkout] → "Continue" → [S-16 Learn Completion]
        │                                               ├── "Practice Now" → [S-13]
        │                                               └── "Back to Home" → [S-09]
        └── "Practice" (completed lessons only) → [S-13 Practice Setup]
              └── "Start" → [S-14 Practice Session]
                    └── ends → [S-15 Checkout] → "Continue" → [S-09]
                                                  "Try Again" → [S-13]
```

---

## Screen Specifications

### S-01 — Splash / Auth Gate
- Show app logo ~1.5s
- Check `FirebaseAuth.currentUser` + `onboardingComplete` in Firestore
- Route accordingly; no back button

### S-02 — Login / Sign-Up
Single screen handling all auth entry points. Priority order top to bottom:

**Primary (fastest, top of screen):**
- Large button: "Continue with Google" (Google logo + text)
  - Calls `google_sign_in` → `GoogleAuthProvider.credential` → `signInWithCredential`
  - New user (no Firestore doc) → `FirestoreService.createUser()` → S-04
  - Returning user → check `onboardingComplete` → S-04 or S-09

- Large button: "Continue as Guest" (person icon + text)
  - Calls `FirebaseAuth.signInAnonymously()`
  - Always → `FirestoreService.createUser(isGuest: true, displayName: "Guest")` → S-04
  - Guest banner shown throughout app (see S-09)

**Divider:** "— or —"

**Secondary (below divider):**
- Tab toggle: "Log In" | "Sign Up"
  - Log In tab: Email + Password fields + "Log In" button
  - Sign Up tab: Display Name + Email + Password fields + "Create Account" button
- Inline errors only (no dialogs)
- Forgot password link on Log In tab (send reset email via Firebase)

**Rules:**
- Google button and Guest button always visible regardless of which tab is active
- No separate Register screen — everything on S-02
- On any successful auth: create Firestore user doc if it doesn't exist, then route

### S-04 — Onboarding Q1: ASL Level
- Progress indicator: step 1 of 4
- TTS reads question on screen entry
- Question: "How much ASL do you know?"
- Options (radio cards):
  - "I know no ASL" → aslLevel: "none"
  - "I know the alphabet" → aslLevel: "alphabet"
  - "I know numbers too" → aslLevel: "numbers"
  - "I can have a basic ASL conversation" → aslLevel: "conversational"
- "Next" button → S-05

### S-05 — Onboarding Q2: Daily Goal
- Progress indicator: step 2 of 4
- TTS reads question on screen entry
- Question: "What's your daily learning goal?"
- Options: "5 minutes 🌱" / "10 minutes ⚡" / "15 minutes 🔥"
- Subtext: "We'll remind you when you're close to your goal"
- "Next" → S-06

### S-06 — Onboarding Q3: Notifications
- Progress indicator: step 3 of 4
- TTS reads screen text on entry
- Title: "I'll remind you to practice so it becomes a habit"
- Body: "Get a daily reminder so you never break your streak"
- Button: "Allow Notifications" → POST_NOTIFICATIONS permission → S-07
- Link: "Maybe later" → skip → S-07 (notificationsEnabled: false)

### S-07 — Onboarding Q4: Starting Point
- Progress indicator: step 4 of 4
- TTS reads question on entry
- Question: "Where would you like to start?"
- Option A: "Start from scratch" → always available
  - set startLessonId from Q1 → write Firestore → initLessons() → S-09
- Option B: "Find my level" → hidden if Q1 == "none"
  - navigate S-08
- Subtext under "Find my level": "Answer 10 quick questions to find your starting point"

### S-08 — Placement Test
- No app bar; no back button
- Header: "Let's find your level"
- 10 items, Hard difficulty, no skip, no TTS prompts
- No XP; no checkout
- On complete: score → startLessonId → Firestore → S-09
- Brief result shown: "You scored X/10 — starting you at [Section Name]"

### S-09 — Home
- App bar: HiASL logo + XP counter "✦ 340 XP" + streak flame + settings icon
- **Guest banner** (shown only if `isGuest == true`):
  - Yellow bar below app bar: "You're in guest mode — Save your progress →"
  - Taps to S-18 (Convert Guest Account)
- Daily quest strip: horizontal scroll, 3 quest cards
- Body: collapsible section cards → lesson cards
  - locked (grey + 🔒) | available | completed (+ ✓)
- TTS reads lesson title on tap

### S-10 — Streak Page
- Current streak (large + flame animation)
- Longest streak
- 30-day activity heatmap
- Motivational message
- Back → S-09

### S-11 — Mode Select
- Lesson title + section name + sign count
- "Learn" (always active)
- "Practice" (disabled if lesson not completed)
- Back → S-09

### S-12 — Learn Session
**Layout:** progress bar | 3D model (rotate/zoom) | sign label (TTS on load) | camera preview | feedback overlay

**State machine:**
```
LOADING → camera activates; TTS reads sign name → DETECTING

DETECTING
  ├── no hand / low confidence → show hint (no sound) → DETECTING
  ├── incorrect → error sound + finger guidance + TTS guidance → DETECTING
  └── correct → success sound + TTS "Correct!" + XP sound → CORRECT

CORRECT (1.5s)
  ├── more signs → load next; TTS reads name → DETECTING
  └── last sign → navigate S-15 (checkout)
```
On exit: `RecognitionController.stopSession()`

### S-13 — Practice Setup
- Difficulty: Easy 🐢 (10s) / Medium ⚡ (7s) / Hard 🔥 (5s), default Easy
- "Start Practice" → S-14

### S-14 — Practice Session
**Layout:** progress + score | "Sign: [LABEL]" prompt (TTS on load) | camera preview | timer bar + Skip

**State machine:**
```
ITEM_START → TTS reads sign → timer starts → WAITING
  ├── correct → success + TTS "Correct!" + XP → ✓ 0.8s → next
  ├── timeout → error + TTS "Time's up" → ✗ 0.8s → next
  └── skip → timeout (no sound)
SESSION_END → S-15
```
No 3D model in Practice mode.

### S-15 — Session Checkout
- Fanfare + animation on entry
- Animated XP counter 0 → earned; TTS "You earned N XP!"
- Accuracy % (green ≥80%, amber ≥60%, red <60%)
- Duration "⏱ 3 min 24 sec"
- Streak row + "Streak extended! ✓" if applicable
- 3 quest progress bars; completed quest → badge + TTS "Quest complete!" + XP sound
- "Continue" → Learn: S-16 | Practice: S-09
- "Try Again" (practice only) → S-13
- Writes: practiceResult to Firestore, XP increment, streak update, quest progress

### S-16 — Learn Completion
- "Lesson complete! 🎉"
- Write status="completed"; unlock next lesson; trigger streak update
- "Practice Now" → S-13 | "Back to Home" → S-09

### S-17 — Settings
- Toggle: Text-to-Speech (default ON)
- Toggle: Sound Effects (default ON)
- Reminder time picker
- Display Name edit
- **"Save Account" button** (shown only if `isGuest == true`) → S-18
- Logout button
- Changes write to Firestore immediately

### S-18 — Convert Guest Account
- Title: "Save your progress"
- Body: "Create an account so you never lose your lessons, XP, or streak"
- Option A: "Continue with Google" → link Google credential to anonymous account
  - `FirebaseAuth.currentUser.linkWithCredential(GoogleAuthProvider.credential)`
  - On success: update user doc (`isGuest: false`, set email + displayName from Google)
  - Navigate back to S-09; dismiss guest banner
- Option B: Email + Password fields → "Create Account"
  - `linkWithCredential(EmailAuthProvider.credential)`
  - On success: update user doc → S-09
- "Not now" link → back to S-09 (data is preserved; still guest)
- All existing Firestore data (lessons, XP, streak) is preserved — same UID throughout

---

## State Management

| State | Provider / Controller |
|---|---|
| Auth state | `FirebaseAuth.authStateChanges()` stream, top-level |
| User profile + settings | `UserProvider` — streams Firestore user doc |
| Onboarding | `OnboardingController` — ephemeral; batch-writes on complete |
| Lesson list + progress | `LessonProvider` — streams lessons subcollection |
| Daily quests | `QuestProvider` — reads/writes dailyQuests/{today} |
| Streak | `StreakProvider` — reads/writes user doc streak fields |
| XP | `XpProvider` — increments user doc totalXp |
| Learn session | `LearnSessionController` — ephemeral |
| Practice session | `PracticeSessionController` — ephemeral |
| Checkout data | `CheckoutData` — nav argument to S-15 |
| Recognition | `RecognitionController` — Stream<RecognitionResult> |
| TTS | `TtsService` — singleton |
| Sound | `SoundService` — singleton |

---

## Service Interfaces

### RecognitionController
```dart
abstract class RecognitionController {
  Stream<RecognitionResult> get results;
  void startSession();
  void stopSession();
}
class RecognitionResult {
  final String label;
  final double confidence;
  final bool handDetected;
  final List<double> landmarks; // 63 floats
}
```

### TtsService
```dart
abstract class TtsService {
  Future<void> speak(String text);
  Future<void> stop();
  bool enabled;
}
```

### SoundService
```dart
abstract class SoundService {
  void playSuccess();
  void playError();
  void playFanfare();
  void playXpGain();
  bool enabled;
}
```

### CheckoutData
```dart
class CheckoutData {
  final int xpEarned;
  final double accuracyPercent;
  final int durationSeconds;
  final String sessionType; // "learn" | "practice"
  final String lessonId;
  final bool streakExtended;
}
```
