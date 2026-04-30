# DATA_SCHEMA.md — Firestore Data Schema
# HiASL

## Collection Structure

```
users/
└── {uid}/
    ├── (profile + streak + XP + settings fields — all inline on user doc)
    ├── lessons/                    # Subcollection — one doc per lesson
    │   └── {lessonId}/
    ├── practiceResults/            # Subcollection — one doc per session
    │   └── {resultId}/
    └── dailyQuests/                # Subcollection — one doc per day
        └── {dateStr}/              # e.g. "2026-04-29"
```

---

## users/{uid} — User Document (all inline fields)

```dart
{
  // Profile
  email: String,
  displayName: String,
  createdAt: Timestamp,
  lastActiveDate: String,       // "YYYY-MM-DD"

  // Onboarding
  onboardingComplete: bool,     // false until onboarding finished
  aslLevel: String,             // "none" | "alphabet" | "numbers" | "conversational"
  dailyGoalMinutes: int,        // 5 | 10 | 15
  notificationsEnabled: bool,
  startLessonId: String,        // e.g. "s1l1" — set at end of onboarding

  // Streak
  currentStreak: int,
  longestStreak: int,
  lastStreakDate: String,        // "YYYY-MM-DD"

  // XP
  totalXp: int,                 // never decreases

  // Settings
  ttsEnabled: bool,             // default true
  soundEnabled: bool,           // default true
}
```

---

## users/{uid}/lessons/{lessonId} — Lesson Progress

`lessonId` = `s{section}l{lesson}` e.g. `"s1l1"`, `"s2l3"`

```dart
{
  lessonId: String,
  sectionNumber: int,           // 1–4
  status: String,               // "locked" | "available" | "completed"
  completedAt: Timestamp?,
  practiceCount: int,
  bestAccuracy: double,         // 0.0–1.0, best practice session accuracy
  totalXpEarned: int,           // cumulative XP from this lesson
}
```

**Gating rules:**
- `s1l1` always `"available"` on account creation (unless placement advances further)
- Lesson N+1 in same section → `"available"` when lesson N `status == "completed"`
- Section 2 lessons → `"locked"` until all Section 1 lessons `"completed"`
- Same rule for Sections 3 and 4
- `startLessonId` on user doc is set to the correct lesson after onboarding; all lessons before it are set to `"completed"` with `completedAt: serverTimestamp()` (so they are skipped cleanly)

---

## users/{uid}/practiceResults/{resultId} — Session Result

`resultId` = Firestore auto-ID

```dart
{
  lessonId: String,
  sessionType: String,          // "learn" | "practice" | "placement"
  difficulty: String,           // "easy" | "medium" | "hard" | "n/a" (for learn)
  completedAt: Timestamp,
  durationSeconds: int,         // total session time
  totalItems: int,
  correctCount: int,
  accuracyPercent: double,      // correctCount / totalItems * 100
  xpEarned: int,                // total XP from this session (0 for placement)
  items: [
    {
      sign: String,             // e.g. "A"
      result: String,           // "correct" | "missed" | "timeout"
      timeTakenMs: int,
    }
  ],
}
```

---

## users/{uid}/dailyQuests/{dateStr} — Daily Quests

`dateStr` = `"YYYY-MM-DD"` (local date)

```dart
{
  date: String,                 // "YYYY-MM-DD"
  generatedAt: Timestamp,
  quests: [
    {
      id: String,               // e.g. "complete_lessons_2"
      type: String,             // "complete_lessons" | "earn_xp" | "practice_sessions" | "correct_streak"
      description: String,      // e.g. "Complete 2 lessons today"
      target: int,              // e.g. 2
      progress: int,            // current count toward target
      completed: bool,
      xpReward: int,            // always 30
    }
  ],
  totalQuestsCompleted: int,
  bonusXpAwarded: int,
}
```

**Quest generation rules (run on first app open each day):**
- Pick 3 quest types randomly from pool; targets scale with user's lesson count
- If `dailyQuests/{today}` doc doesn't exist → generate and write
- If doc exists → read and display (do not regenerate)

**Quest pool:**
```dart
const kQuestPool = [
  { type: 'complete_lessons',    target: 1, description: 'Complete 1 lesson today' },
  { type: 'complete_lessons',    target: 2, description: 'Complete 2 lessons today' },
  { type: 'earn_xp',            target: 50,  description: 'Earn 50 XP today' },
  { type: 'earn_xp',            target: 100, description: 'Earn 100 XP today' },
  { type: 'practice_sessions',  target: 1, description: 'Complete 1 practice session' },
  { type: 'practice_sessions',  target: 3, description: 'Complete 3 practice sessions' },
  { type: 'correct_streak',     target: 5, description: 'Get 5 signs correct in a row' },
  { type: 'correct_streak',     target: 10, description: 'Get 10 signs correct in a row' },
];
```

---

## Local Constants (NOT in Firestore)

### Lesson Definitions
```dart
// lib/data/lesson_definitions.dart

class LessonDefinition {
  final String id;
  final int section;
  final String title;
  final List<String> signs;   // sign labels e.g. ['A','B','C']
}

const kLessons = [
  LessonDefinition(id:'s1l1', section:1, title:'Alphabet A–E',       signs:['A','B','C','D','E']),
  LessonDefinition(id:'s1l2', section:1, title:'Alphabet F–J',       signs:['F','G','H','I','J']),
  LessonDefinition(id:'s1l3', section:1, title:'Alphabet K–O',       signs:['K','L','M','N','O']),
  LessonDefinition(id:'s1l4', section:1, title:'Alphabet P–T',       signs:['P','Q','R','S','T']),
  LessonDefinition(id:'s1l5', section:1, title:'Alphabet U–Z',       signs:['U','V','W','X','Y','Z']),
  LessonDefinition(id:'s1l6', section:1, title:'Numbers 0–4',        signs:['0','1','2','3','4']),
  LessonDefinition(id:'s1l7', section:1, title:'Numbers 5–9',        signs:['5','6','7','8','9']),
  LessonDefinition(id:'s2l1', section:2, title:'Short Words',        signs:['C','A','T','D','O','G']), // letters used in words
  LessonDefinition(id:'s2l2', section:2, title:'Spell Your Name',    signs:[]), // dynamic, from displayName
  LessonDefinition(id:'s2l3', section:2, title:'Common Words',       signs:['F','I','S','H','B','O','K']),
  LessonDefinition(id:'s2l4', section:2, title:'Longer Words',       signs:['A','P','L','E','H','O','U','S']),
  LessonDefinition(id:'s2l5', section:2, title:'Speed Challenge',    signs:['A','B','C','D','E','F','G','H','I','J']),
  LessonDefinition(id:'s3l1', section:3, title:'Count 0–9',         signs:['0','1','2','3','4','5','6','7','8','9']),
  LessonDefinition(id:'s3l2', section:3, title:'Random Numbers',    signs:['0','1','2','3','4','5','6','7','8','9']),
  LessonDefinition(id:'s3l3', section:3, title:'Number Pairs',      signs:['1','2','3','4','5','6','7','8','9','0']),
  LessonDefinition(id:'s3l4', section:3, title:'Number Expressions',signs:['1','2','3','4','5']),
  LessonDefinition(id:'s4l1', section:4, title:'Full Alphabet Review',signs:['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']),
  LessonDefinition(id:'s4l2', section:4, title:'Alphabet Speed Run', signs:['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']),
  LessonDefinition(id:'s4l3', section:4, title:'Numbers + Letters',  signs:['A','B','C','1','2','3','D','E','F','4','5','6']),
  LessonDefinition(id:'s4l4', section:4, title:'Mastery Test',       signs:[]), // dynamic: 30 random from full set
];
```

### Section Definitions
```dart
class SectionDefinition {
  final int number;
  final String title;
  final String description;
}

const kSections = [
  SectionDefinition(number:1, title:'Foundations',             description:'Learn every letter and number'),
  SectionDefinition(number:2, title:'Fingerspelling Practice', description:'Spell real words'),
  SectionDefinition(number:3, title:'Numbers in Context',      description:'Use numbers naturally'),
  SectionDefinition(number:4, title:'Mixed Review & Mastery',  description:'Prove what you know'),
];
```

### Difficulty → Time Limit
```dart
const kDifficultySeconds = { 'easy': 10, 'medium': 7, 'hard': 5 };
```

### XP Awards
```dart
const kXpLearnCorrect   = 10;
const kXpPracticeEasy   = 15;
const kXpPracticeMedium = 20;
const kXpPracticeHard   = 25;
const kXpPerfectBonus   = 50;
const kXpStreakBonus     = 100;   // every 7-day milestone
const kXpQuestBonus     = 30;    // per completed quest
```

### Sign Label Map (TFLite class index → label)
⚠️ Confirm this order from `keypoint_classifier_label.csv` after retraining.
Update this map to match your actual CSV before writing RecognitionController.

```
0→A, 1→B, 2→C, 3→D, 4→E, 5→F, 6→G, 7→H, 8→I, 9→J,
10→K, 11→L, 12→M, 13→N, 14→O, 15→P, 16→Q, 17→R, 18→S, 19→T,
20→U, 21→V, 22→W, 23→X, 24→Y, 25→Z,
26→0, 27→1, 28→2, 29→3, 30→4, 31→5, 32→6, 33→7, 34→8, 35→9
```
Also copy CSV to `assets/models/keypoint_classifier_label.csv` — one label per line.

### Finger-State Target Map
Finger order: `[thumb, index, middle, ring, pinky]`
States: `"extended"` | `"curled"` | `"any"`

Extended = tip.y < pip.y (normalised x,y coords — z not used)
Curled   = tip.y > pip.y
Only x and y values used from MediaPipe output — drop z before processing.

```dart
const kSignFingerStates = {
  'A': ['curled','curled','curled','curled','curled'],
  'B': ['curled','extended','extended','extended','extended'],
  'C': ['any','any','any','any','any'],   // curved — use shape classifier fallback
  'D': ['any','extended','curled','curled','curled'],
  'E': ['curled','curled','curled','curled','curled'],  // fingers bent at middle joint
  'F': ['any','curled','extended','extended','extended'],
  'G': ['extended','extended','curled','curled','curled'],
  'H': ['curled','extended','extended','curled','curled'],
  'I': ['curled','curled','curled','curled','extended'],
  'J': ['curled','curled','curled','curled','extended'],  // + motion (note motion not checked)
  'K': ['extended','extended','extended','curled','curled'],
  'L': ['extended','extended','curled','curled','curled'],
  'M': ['curled','curled','curled','curled','curled'],
  'N': ['curled','curled','curled','curled','curled'],
  'O': ['any','any','any','any','any'],
  'P': ['extended','extended','extended','curled','curled'],
  'Q': ['extended','extended','curled','curled','curled'],
  'R': ['curled','extended','extended','curled','curled'],
  'S': ['curled','curled','curled','curled','curled'],
  'T': ['extended','curled','curled','curled','curled'],
  'U': ['curled','extended','extended','curled','curled'],
  'V': ['curled','extended','extended','curled','curled'],
  'W': ['curled','extended','extended','extended','curled'],
  'X': ['curled','extended','curled','curled','curled'],
  'Y': ['extended','curled','curled','curled','extended'],
  'Z': ['curled','extended','curled','curled','curled'],  // + motion
  '0': ['any','any','any','any','any'],
  '1': ['curled','extended','curled','curled','curled'],
  '2': ['curled','extended','extended','curled','curled'],
  '3': ['extended','extended','extended','curled','curled'],
  '4': ['curled','extended','extended','extended','extended'],
  '5': ['extended','extended','extended','extended','extended'],
  '6': ['any','extended','extended','extended','curled'],
  '7': ['any','extended','extended','curled','extended'],
  '8': ['any','extended','extended','curled','curled'],
  '9': ['any','extended','curled','curled','curled'],
};
```

Guidance message template: `"${action} your ${finger} finger"`
- action: "Extend" if expected=extended but observed=curled; "Curl" if opposite
- Report only the FIRST mismatching finger per attempt

---

## Streak Update Logic
```
On session complete → read lastStreakDate:
  == today        → no change (already counted)
  == yesterday    → currentStreak += 1, lastStreakDate = today
  < yesterday     → currentStreak = 1,  lastStreakDate = today
Always: if currentStreak > longestStreak → longestStreak = currentStreak
If currentStreak % 7 == 0 → award kXpStreakBonus
```

---

## Firestore Security Rules
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---
## Amendment — Quick Auth Fields (appended)

### users/{uid} — Additional fields

```dart
// Add these fields to the user doc
isGuest: bool,          // true if signed in anonymously; false after conversion or email/Google sign-up
authProvider: String,   // "google" | "email" | "anonymous"
```

### createUser() — Behaviour by auth method

| Auth Method | displayName source | isGuest | authProvider |
|---|---|---|---|
| Google Sign-In | Google account name | false | "google" |
| Anonymous | "Guest" (hardcoded) | true | "anonymous" |
| Email Sign-Up | User-entered field | false | "email" |

### Guest Account Conversion — Data Handling
- `FirebaseAuth.currentUser.linkWithCredential(credential)` preserves the UID
- All Firestore data under `users/{uid}/` is automatically preserved (same path)
- After conversion: update user doc fields: `isGuest: false`, `authProvider: "google"` or `"email"`, set `email` + `displayName` from new credential
- No data migration needed — UID does not change
