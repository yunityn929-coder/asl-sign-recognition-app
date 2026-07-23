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
    ├── dailyQuests/                # Subcollection — one doc per day
    │   └── {dateStr}/              # e.g. "2026-04-29"
    └── calibration/                # Subcollection — one doc per sign label
        └── {signLabel}/

deletedGoogleAccounts/              # Top-level collection — Google-identity blocklist
└── {googleUid}/                    # doc ID = the deleted account's Google provider UID
```

---

## users/{uid} — User Document (all inline fields)

```dart
{
  // Profile
  email: String,
  displayName: String,
  photoUrl: String,             // '' until a Google account is linked/signed in
  createdAt: Timestamp,
  lastActiveDate: String,       // "YYYY-MM-DD"

  // Onboarding
  onboardingComplete: bool,     // false until onboarding finished
  aslLevel: String,             // "none" | "alphabet" | "conversational"
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

  // Sign Progress
  signAccuracy: Map<String, double>, // per-sign accuracy, weighted avg (0.0-1.0), keyed by sign label
                                      // — see updateSignAccuracy() in firestore_service.dart
}
```

> NOTE: `markLessonComplete()` also writes `signsLearned: FieldValue.increment(signCount)`
> to the user doc, but `UserModel` has no `signsLearned` field — it's written but never
> read back into the app.

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

> NOTE: `items` array is always written as `[]` currently — per-sign timing (`timeTakenMs`)
> is not tracked. `durationSeconds` is also hardcoded to `0` (not measured). Per-sign
> accuracy is tracked via `signAccuracy` on the user doc instead (see `updateSignAccuracy()`).

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

> NOTE: `correct_streak` exists in `kQuestPool` (`lib/data/quest_pool.dart`) but is excluded
> from `_kDailyQuestTypes` in `firestore_service.dart` — it is filtered out at generation
> time, so users can never actually receive this quest. Only `complete_lessons`, `earn_xp`,
> and `practice_sessions` are ever generated and updated via `updateQuestProgress()`.

---

## deletedGoogleAccounts/{googleUid} — Deleted-Account Blocklist

`googleUid` = the Google auth provider's own UID (not the Firebase UID)

```dart
{
  deletedAt: Timestamp,          // FieldValue.serverTimestamp()
  firebaseUid: String,           // the Firebase Auth uid that was deleted
}
```

**Purpose:** when a user with a linked Google account deletes their profile,
their Google identity is recorded here so `AuthService.signInWithGoogle()`
can refuse future **Sign In** attempts with that Google account ("This
Google account was previously deleted from HiASL and can no longer sign
in."). This only blocks **Sign In** (`signInWithGoogle()` / `SignInScreen`)
— it does NOT block **Create Profile** (`linkWithGoogle()` /
`LinkAccountScreen`), so a deleted Google identity can always be freely
re-registered as a brand-new anonymous profile.

**Write ordering (matters for Firestore rules):** the blocklist record is
written **before** `user.delete()` in `AuthService.deleteAccount()`, not
after — writing it after would fail with `PERMISSION_DENIED` because
`request.auth` becomes null the instant the Firebase Auth user is deleted,
and the rule requires an authenticated `request.auth.uid` matching
`firebaseUid`. If `user.delete()` then fails or requires re-authentication,
the record is rolled back (deleted) so a still-live account isn't
incorrectly blocklisted.

### Local Quiz Data (NOT in Firestore)

**QuizSet** (lib/data/quiz_definitions.dart)
| Field | Type | Notes |
|-------|------|-------|
| id | String | section_1/section_2/section_3/section_4/quick |
| title | String | Display name |
| description | String | Short subtitle |
| signs | List<String> | Signs used in this quiz |
| sectionNumber | int | 0 = quick quiz |

**QuizQuestion** (lib/models/quiz_question.dart)
| Field | Type | Notes |
|-------|------|-------|
| correctSign | String | The correct answer |
| options | List<String> | 4 options including correct |
| type | QuestionType | imageToLetter/letterToImage/letterToLetter |
| timeSeconds | int | Always 10 |

Quiz best scores stored in SharedPreferences:
key: `quiz_best_{quizSetId}` → int (correct count out of 10)

**Auth — device-local anonymous UID tracking** (`lib/services/auth_service.dart`):
key: `native_anonymous_uid` → String (Firebase UID)
Set the first time this device creates or reuses an anonymous session. Used
by `AuthService.signOut()` to decide sign-out behaviour — see the Sign Out
amendment below.

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
  LessonDefinition(id:'s1l1', section:1, title:'Alphabet A–E',  signs:['A','B','C','D','E']),
  LessonDefinition(id:'s1l2', section:1, title:'Alphabet F–J',  signs:['F','G','H','I','J']),
  LessonDefinition(id:'s1l3', section:1, title:'Alphabet K–O',  signs:['K','L','M','N','O']),
  LessonDefinition(id:'s1l4', section:1, title:'Alphabet P–T',  signs:['P','Q','R','S','T']),
  LessonDefinition(id:'s1l5', section:1, title:'Alphabet U–Z',  signs:['U','V','W','X','Y','Z']),
  LessonDefinition(id:'s2l1', section:2, title:'Short Words',   signs:['C','A','T','D','O','G']),
  LessonDefinition(id:'s2l2', section:2, title:'Spell Your Name', signs:[]),
  LessonDefinition(id:'s2l3', section:2, title:'Common Words',  signs:['F','I','S','H','B','O','K']),
  LessonDefinition(id:'s2l4', section:2, title:'Longer Words',  signs:['A','P','L','E','H','O','U','S']),
  LessonDefinition(id:'s2l5', section:2, title:'Speed Challenge', signs:['A','B','C','D','E','F','G','H','I','J']),
  LessonDefinition(id:'s3l1', section:3, title:'Full Alphabet Review', signs:['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']),
  LessonDefinition(id:'s3l2', section:3, title:'Alphabet Speed Run',   signs:['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']),
  LessonDefinition(id:'s3l3', section:3, title:'Mixed Review',         signs:['A','B','C','D','E','F','G','H','I','J','K','L']),
  LessonDefinition(id:'s3l4', section:3, title:'Mastery Test',         signs:[]),
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
  SectionDefinition(number:1, title:'Foundations',             description:'Learn every letter A–Z'),
  SectionDefinition(number:2, title:'Fingerspelling Practice', description:'Spell real words'),
  SectionDefinition(number:3, title:'Review & Mastery',        description:'Put it all together'),
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
```
 0→0,  1→1,  2→2,  3→3,  4→4,  5→5,  6→6,  7→7,  8→8,  9→9,
10→A, 11→B, 12→C, 13→D, 14→E, 15→F, 16→G, 17→H, 18→I, 19→J,
20→K, 21→L, 22→M, 23→N, 24→O, 25→P, 26→Q, 27→R, 28→S, 29→T,
30→U, 31→V, 32→W, 33→X, 34→Y, 35→Z
```
Defined as `kSignLabels` in `lib/data/sign_label_map.dart` — no separate label file is bundled with the app.

### Finger-State Target Map
Finger order: `[thumb, index, middle, ring, pinky]`
States: `"extended"` | `"curled"` | `"any"`

Extended = tip.y < pip.y (normalised coords)
Curled   = tip.y > pip.y

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

> NOTE: `streakGoalAchieved` is never set to `true` by any code path.
> `updateStreakIfNeeded()` updates `currentStreak`/`longestStreak`/`lastStreakDate` only —
> `kXpStreakBonus` (100 XP/7-day milestone) is defined in `xp_constants.dart` but is never
> referenced anywhere else; no bonus XP is actually awarded for streak milestones.

---

## Firestore Security Rules
See `firestore.rules` in the repo root for the authoritative, current rules
(they're validated/deployed separately from this doc and can drift — always
check the file itself before relying on this summary).

Current shape, summarised:
```
users/{uid}                        — read/create/update/delete: owner only
                                      (create/update also schema-validated)
users/{uid}/lessons/{lessonId}     — owner only, schema-validated on write
users/{uid}/practiceResults/{id}   — owner create/read/delete; update: false
users/{uid}/dailyQuests/{dateStr}  — owner only, dateStr format validated
users/{uid}/calibration/{sign}     — owner only, schema-validated on write

deletedGoogleAccounts/{googleUid}  — read: any authenticated user
                                    — create: only by the uid matching
                                      the doc's own firebaseUid field
                                    — update: false (immutable once written)
                                    — delete: only by the uid matching
                                      the doc's own firebaseUid field
                                      (used for the rollback path)

{everything else}                  — read, write: false (deny by default)
```

---

> SUMMARY: The authoritative auth model is the final amendment (No-Login-First). Anonymous
> sign-in on launch, Google Sign-In available via Leaderboard gate or Profile screen upgrade
> prompt. Email/password auth was removed entirely.

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

---
## Amendment — No-Login-First + Streak Goal (appended)

### users/{uid} — Additional/Changed Fields

```dart
// Auth
isAnonymous: bool,          // true until Google Sign-In linked
authProvider: String,       // "anonymous" | "google"

// Streak Goal (new — set during onboarding S-12)
streakGoalDays: int,        // 7 | 14 | 30 | 50
streakGoalStartDate: String, // "YYYY-MM-DD" when goal was set
streakGoalAchieved: bool,   // true when currentStreak >= streakGoalDays
```

### createUser() — anonymous flow
```dart
// Called silently on first launch (no UI)
{
  displayName: "Learner",   // default until onboarding complete
  isAnonymous: true,
  authProvider: "anonymous",
  onboardingComplete: false,
  streakGoalDays: 7,        // default, updated in S-12
  streakGoalStartDate: "",
  streakGoalAchieved: false,
  // all other fields same as before
}
```

### Streak Goal XP Rewards
```dart
const kStreakGoalXp = {
  7:  100,
  14: 250,
  30: 500,
  50: 1000,
};
```

### Checkout Screen Labels (for accuracy display)
```dart
// accuracyPercent → label
≥ 90% → "AMAZING"
≥ 70% → "GREAT"
≥ 50% → "GOOD"
< 50%  → "KEEP TRYING"
```

### Mascot Name
The HiASL mascot is named **"Hani"** — used in all speech bubbles throughout onboarding.

---
## Amendment — Two-Screen Google Auth, Blocklist, Unlink Sign-Out (appended 2026-07-23)

This supersedes the auth behaviour described in the earlier amendments above
wherever they conflict. See TECH_STACK.md's "Auth Flow" section for the full
code-level walkthrough; this amendment covers the Firestore/data-model
implications only.

- **Two separate screens, not one:** `LinkAccountScreen` (Create Profile,
  `linkWithCredential` — upgrades the current anonymous session in place,
  same UID, all progress preserved) and `SignInScreen` (Sign In,
  `signInWithCredential` — switches to a different existing account, a
  different UID). See DATA_SCHEMA.md's `deletedGoogleAccounts` section and
  APP_FLOW.md S-25/S-25b for the full behavioural split.
- **`photoUrl`** is now a real field on `users/{uid}` (see the User Document
  section above) — populated from the Google account's `photoUrl` at link
  or sign-in time, `''` for anonymous/unlinked users.
- **`deletedGoogleAccounts` blocklist** (new top-level collection) — see its
  own section above.
- **Sign Out is no longer a single unconditional `signOut()` call.** It now
  distinguishes two cases via the device-local `native_anonymous_uid`
  SharedPreferences key (see Local Constants above):
  - If the currently-linked Google account originated from **this device's
    own** anonymous session (`current.uid == nativeUid`) → `unlink('google.com')`
    instead of a full sign-out. The anonymous session (and all its Firestore
    data) survives; the user just drops back to guest/anonymous state on the
    same UID.
  - Otherwise (the account was reached via a true Sign In switch to a
    different pre-existing account, or this device never held that account
    natively) → full `FirebaseAuth.signOut()`, which then triggers a fresh
    anonymous session on next launch.
- **Delete Account ordering:** `FirestoreService.deleteUserData(uid)` (all
  subcollections, then the user doc) runs first, then
  `AuthService.deleteAccount()` (blocklist write, then `user.delete()`) runs
  second — see `deleteUserData()` in `firestore_service.dart` and
  `deleteAccount()` in `auth_service.dart`.
