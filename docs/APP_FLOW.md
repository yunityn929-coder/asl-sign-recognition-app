# APP_FLOW.md — Screen Map & Navigation
# HiASL

## Screen Inventory

| ID | Name | Route | Notes |
|---|---|---|---|
| S-01 | Splash | `/` |
| S-02 | Welcome — Brand | `/welcome/brand` |
| S-03 | Welcome — Mascot Intro | `/welcome/intro` |
| S-04 | Welcome — Questions Preview | `/welcome/preview` |
| S-05 | Onboarding Q1: ASL Level | `/onboarding/level` |
| S-06 | Onboarding Q2: Daily Goal | `/onboarding/goal` |
| S-07 | Onboarding Q3: Notifications | `/onboarding/notifications` |
| S-08 | Onboarding Q4: Achievement Preview | `/onboarding/achievement` |
| S-09 | Onboarding Q5: Starting Point | `/onboarding/start` | ORPHANED (removed from flow) |
| S-10 | Placement Test | `/onboarding/placement` | ORPHANED (removed from flow) |
| S-11 | Placement Result | `/onboarding/placement-result` | ORPHANED (removed from flow) |
| S-12 | Streak Goal Selection | `/onboarding/streak-goal` |
| S-13 | Home (Section + Lesson List) | `/home` |
| S-14 | Streak Page | `/streak` |
| S-15 | Mode Select | `/lesson/:lessonId/mode` |
| S-16 | Learn Session | `/lesson/:lessonId/learn` | ORPHANED (exercise_screen used) |
| S-17 | Practice Setup | `/lesson/:lessonId/practice/setup` |
| S-18 | Practice Session | `/lesson/:lessonId/practice/session` |
| S-19 | Session Checkout | `/session/checkout` |
| S-20 | Learn Completion | `/lesson/:lessonId/complete` | ORPHANED (results_screen used) |
| S-21 | Post-Checkout Streak Born | `/session/streak` |
| S-22 | Daily Quest Update | `/session/quest` |
| S-23 | Settings | `/settings` |
| S-24 | Leaderboard (login-gated) | `/leaderboard` |
| S-25 | Google Sign-In (social unlock) | `/login/social` |
| S-26 | Quiz Home | `/quiz` | |
| S-27 | Quiz Session | `/quiz/session` | |
| S-28 | Quiz Result | `/quiz/result` | |

**Bottom Nav:** Home | Quiz | Signs | Profile
(Quest is accessible via the Daily Quests card on Home, not a tab)

---

## Navigation Flow

> NOTE (2026-07-18): Two separate post-lesson flows exist:
> - Learn mode ends: Exercise → Results → Home
>   (does NOT go through Checkout flow)
> - Practice mode ends: Practice Session → Checkout →
>   (Streak Born if streak extended) → Quest Update → Home

```
FIRST LAUNCH:
[S-01 Splash]
  → Firebase.signInAnonymously() silently in background
  → onboardingComplete == false → [S-02 Welcome Brand]

WELCOME FLOW (first launch only, shown in sequence):
[S-02] → [S-03 Mascot Intro] → [S-04 Questions Preview]
  → [S-05 Q1: ASL Level]
  → [S-06 Q2: Daily Goal]
  → [S-07 Q3: Notifications]
  → [S-08 Achievement Preview]
  → [S-12 Streak Goal]
        (ASL level answer auto-maps to startLessonId:
         none → s1l1, some → s1l3,
         alphabet → s2l1, conversational → s3l1)
  → [S-13 Home]

NOTE: S-09 Starting Point, S-10 Placement Test, and S-11
Placement Result are ORPHANED — not reachable from this flow.

RETURNING USER:
[S-01 Splash] → onboardingComplete == true → [S-13 Home]

HOME FLOW:
[S-13 Home]
  ├── streak icon → [S-14 Streak]
  ├── settings icon → [S-23 Settings]
  ├── leaderboard icon → [S-24 Leaderboard]
  │     └── "Login to join" → [S-25 Google Sign-In]
  │           → link anonymous account → back to [S-24]
  └── tap lesson → [S-15 Mode Select]
        ├── "Learn" → [S-16 Learn Session]
        │     → ends → [S-19 Checkout]
        │           → "Continue" → [S-21 Streak Born] (if first today)
        │                        → [S-22 Quest Update]
        │                        → [S-20 Learn Completion]
        │                              ├── "Practice Now" → [S-17]
        │                              └── "Back to Home" → [S-13]
        └── "Practice" → [S-17 Practice Setup]
              → [S-18 Practice Session]
              → [S-19 Checkout]
              → "Continue" → [S-21] (if first today) → [S-22] → [S-13]
              → "Try Again" → [S-17]
```

---

## Screen Specifications

### S-01 — Splash
- Show HiASL logo ~1.5s
- Call `FirebaseAuth.signInAnonymously()` silently (no UI)
- Check `onboardingComplete` on user Firestore doc
- Route to S-02 (first launch) or S-13 (returning)
- No back button

### S-02 — Welcome: Brand Screen
- Full screen: HiASL mascot (hand signing) + large logo
- Tagline: "Learn ASL. For free. Forever."
- Button: "GET STARTED" → S-03
- Small link: "I already have an account" → S-25 (Google Sign-In to restore progress)
- No back button

### S-03 — Welcome: Mascot Intro
- Dark background, mascot centre screen
- Speech bubble: "Hi there! I'm Hani! 🤟"
- Subtext: "I'll be your ASL learning buddy"
- Button: "CONTINUE" → S-04
- Back arrow → S-02

### S-04 — Welcome: Questions Preview
- Mascot with excited expression
- Speech bubble: "Just **4 quick questions** before we start your first lesson!"
- Button: "CONTINUE" → S-05
- Back arrow → S-03

### S-05 — Onboarding Q1: ASL Level
- Progress bar: step 1 of 4 (top)
- Mascot top-left with speech bubble: "How much ASL do you know?"
- TTS reads question on entry
- Radio option cards (full width, with signal bar icon like Duolingo):
  - 📶 "I'm new to ASL"
  - 📶 "I know some signs"
  - 📶 "I know the alphabet"
  - 📶 "I can have a basic ASL conversation"
- Selected card highlights in app accent colour
- "CONTINUE" button (disabled until selection made) → S-06

### S-06 — Onboarding Q2: Daily Goal
- Progress bar: step 2 of 4
- Mascot with speech bubble: "What's your daily learning goal?"
- TTS reads on entry
- Option cards with right-aligned label:
  - "5 min / day" — Casual
  - "10 min / day" — Regular
  - "15 min / day" — Serious
  - "20 min / day" — Intense
- "I'M COMMITTED" button (disabled until selected) → S-07

### S-07 — Onboarding Q3: Notifications
- Progress bar: step 3 of 4
- Mascot with speech bubble: "I'll remind you to practice so it becomes a habit!"
- System notification permission dialog triggered on button tap
- Button: "REMIND ME TO PRACTICE" → request POST_NOTIFICATIONS → S-08
- Small link: "Maybe later" → S-08 (notificationsEnabled: false)

### S-08 — Onboarding: Achievement Preview
- Progress bar: step 4 of 4
- Mascot with speech bubble: "Here's what you can achieve!"
- 3 feature highlights with icons:
  - 🤟 "Sign with confidence — Learn every letter and number"
  - ⚡ "Build your vocabulary — Fingerspell real words"
  - 🔥 "Develop a habit — Streaks, quests, and daily goals"
- Button: "CONTINUE" → S-09

### S-09 — Onboarding Q4: Starting Point
- Mascot with speech bubble: "Where would you like to start?"
- Two large option cards:
  - 📖 **"Start from scratch"** — "Take the easiest lesson of the ASL course"
  - 🧭 **"Find my level"** *(RECOMMENDED badge)* — "Let me recommend where you should start"
    - Hidden/disabled if Q1 = "I'm new to ASL"
- "CONTINUE" button → routes based on selection
- No progress bar (this is the last question)

### S-10 — Placement Test
- Header: "Let's find your level"
- Mascot small top-left
- 10 random signs from entry section for Q1 answer
- Practice-style session: Hard difficulty (5s), no skip, no TTS prompts
- Progress bar shows items completed
- No XP, no checkout after
- On complete → navigate S-11

### S-11 — Placement Result
- Celebration screen (coloured background like Duolingo image 20)
- Mascot animated celebration
- Text: "Since you know [Q1 answer], you should start with **[Section Name]**!"
- Button: "LET'S GO" → initLessons(startLessonId) → S-12

### S-12 — Streak Goal Selection
- Mascot with speech bubble: "Let's commit to learning with a Streak Goal!"
- Mascot + flame icon
- Option cards with right-aligned reward:
  - "7 days" — +100 XP bonus
  - "14 days" — +250 XP bonus
  - "30 days" — +500 XP bonus
  - "50 days" — +1000 XP bonus
- "COMMIT TO MY GOAL" button → write streakGoalDays to Firestore → S-13
- Write `onboardingComplete: true` here

### S-13 — Home
- App bar: HiASL logo + XP counter "✦ 340 XP" + streak flame + leaderboard icon + settings icon
- Daily quest strip: horizontal scroll, 3 quest cards below app bar
- Body: collapsible section cards → lesson cards
  - locked (grey + 🔒) | available | completed (+ ✓)
- TTS reads lesson title on tap

### S-14 — Streak Page
- Large streak count + flame animation
- Weekly calendar heatmap (dots)
- Streak goal progress (e.g. "5 / 7 days toward your goal")
- Motivational message
- Back → S-13

### S-15 — Mode Select
- Lesson title + section name + sign count
- "Learn" (always active)
- "Practice" (disabled if lesson not completed)
- Back → S-13

### S-16 — Learn Session
**Layout:** progress bar | 3D model (rotate/zoom) | sign label (TTS on load) | camera preview | feedback overlay

**State machine:**
```
LOADING → camera activates; TTS reads sign name → DETECTING

DETECTING
  ├── no hand / low confidence → show hint (no sound) → DETECTING
  ├── incorrect → error sound + finger guidance + TTS → DETECTING
  └── correct → success sound + TTS "Correct!" + XP sound → CORRECT

CORRECT (1.5s)
  ├── more signs → load next; TTS reads name → DETECTING
  └── last sign → navigate S-19 (checkout)
```
On exit: `RecognitionController.stopSession()`

### S-17 — Practice Setup
- Difficulty: Easy 🐢 (10s) / Medium ⚡ (7s) / Hard 🔥 (5s)
- Default: Easy
- "Start Practice" → S-18

### S-18 — Practice Session
**Layout:** progress + score | "Sign: [LABEL]" (TTS on load) | camera preview | timer bar + Skip

**State machine:**
```
ITEM_START → TTS reads sign → timer → WAITING
  ├── correct → success + TTS + XP → ✓ 0.8s → next
  ├── timeout → error + TTS "Time's up" → ✗ 0.8s → next
  └── skip → timeout (no sound)
SESSION_END → S-19
```

### S-19 — Session Checkout
Inspired by Duolingo image 15 — celebration layout.

- Full screen, coloured background (accent colour)
- Mascot animated (jumping/celebrating) at top
- Title: "Amazing!" / "Learning legend!" / "Great work!" (random positive)
- 3 stat cards in a row:
  - 🟡 "TOTAL XP" — animated counter → earned XP
  - 🟢 "ACCURACY" — percentage with label (AMAZING/GOOD/KEEP TRYING)
  - 🔵 "TIME" — session duration (mm:ss) with label "COMMITTED"
- Fanfare sound on entry
- TTS: "You earned {N} XP!"
- Button: "CLAIM XP" → animate XP into total → navigate:
  - If streak extended today → S-21 (Streak Born)
  - Else → S-22 (Quest Update)
  - From Learn → eventually S-20
  - From Practice → eventually S-13

### S-20 — Learn Completion
- "Lesson complete! 🎉"
- Write status="completed"; unlock next lesson; trigger streak
- "Practice Now" → S-17 | "Back to Home" → S-13

### S-21 — Streak Born / Extended
Inspired by Duolingo image 17.

- Mascot hugging flame icon
- Large number: current streak count
- Text: "day streak" below number
- Weekly calendar row (Tu/We/Th... dots, today checked ✓)
- Message: "A streak is born! Practice every day to build a habit." (day 1)
         OR "🔥 Keep it up! You're on a roll." (day 2+)
- Button: "I'M COMMITTED" → S-22

### S-22 — Daily Quest Update
Inspired by Duolingo image 19.

- Title: "Daily Quest update!" (in accent colour)
- Shows updated quest card with progress bar
- e.g. "Complete your next 2 lessons — 1/2 ●●○"
- If quest just completed → show completion badge + TTS "Quest complete!"
- Button: "CONTINUE" → S-20 (from learn) or S-13 (from practice)

### S-23 — Settings
- Toggle: TTS (default ON)
- Toggle: Sound Effects (default ON)
- Reminder time picker
- Streak goal change
- "Back up my progress" → S-25 (Google Sign-In)
- App version

### S-24 — Leaderboard (Login-Gated)
- Blurred/locked preview of leaderboard rankings
- Overlay: "Login to join the leaderboard"
- Button: "CONTINUE WITH GOOGLE" → S-25
- Back → S-13

### S-25 — Google Sign-In (Social Unlock)
- Shown only when user wants social features or backup
- Title: "Save your progress & join the leaderboard"
- Button: "Continue with Google"
  - `currentUser.linkWithCredential(GoogleAuthProvider)`
  - Update Firestore: `isAnonymous: false`, set email + displayName
  - On success: navigate back to where user came from
- "Not now" → back

### Quiz Tab (New — Added 2026-07-18)

**Quiz Home (/quiz)**
- Section quizzes (4 sections, locked by lesson progress)
- Quick Quiz (10 random signs, always available)
- Best scores tracked via SharedPreferences
- Navigates to /quiz/session with QuizSet as extra

**Quiz Session (/quiz/session)**
- Receives QuizSet via route extra
- 10 questions, 10 seconds each
- Mixed types: imageToLetter / letterToImage / letterToLetter
- PNG hand sign images from assets/models/3d/
- App-themed option buttons (4 colors)
- Score tracking, XP per correct answer
- Navigates to /quiz/result via pushReplacement

**Quiz Result (/quiz/result)**
- Shows score, accuracy, XP earned
- Saves XP to Firestore via userActionsProvider
- Saves best score to SharedPreferences
- Shows weak signs (wrong answers) with practice button
- Play Again or Back to Quizzes

---

## State Management

| State | Provider |
|---|---|
| Auth state | `FirebaseAuth.authStateChanges()` top-level |
| User profile + settings | `UserProvider` — streams Firestore user doc |
| Onboarding answers | `OnboardingController` — ephemeral, batch write on S-12 |
| Lesson list + progress | `LessonProvider` — streams lessons subcollection |
| Daily quests | `QuestProvider` |
| Streak + streak goal | `StreakProvider` |
| XP | `XpProvider` |
| Learn session | `LearnSessionController` — ephemeral |
| Practice session | `PracticeSessionController` — ephemeral |
| Checkout data | `CheckoutData` — nav argument |
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
  final List<double> landmarks;
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
