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

  // Gamification — see GAMIFICATION.md for full behaviour
  medalsEarned: Map<String, bool>,   // keyed "{lessonId}_{difficulty}", e.g. "s1l1_easy" — see GAMIFICATION.md
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
      completed: bool,          // true once progress >= target
      xpReward: int,            // varies per quest def, see kQuestPool
      collected: bool,          // true once the user tapped the Quest
                                 // screen's treasure chest to claim xpReward
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

> NOTE (current behaviour, supersedes the spec above): `kQuestPool`
> (`lib/data/quest_pool.dart`) is a **fixed** set of exactly 3 quests, the
> same every day — there is no random selection and no `practice_sessions`
> or `correct_streak` type:
> ```dart
> const kQuestPool = [
>   QuestDefinition(type: 'high_score_lessons', target: 3, description: 'Score 90% or above in 3 lessons', xpReward: 10),
>   QuestDefinition(type: 'spend_minutes',      target: 0, description: 'Spend time learning',              xpReward: 10),
>   QuestDefinition(type: 'earn_xp',            target: 100, description: 'Earn 100 XP',                    xpReward: 20),
> ];
> ```
> `spend_minutes`' `target: 0` is a sentinel — its real target is resolved
> per-user at generation/reconcile time as `user.dailyGoalMinutes * 60`
> (seconds), where `dailyGoalMinutes` is the answer to the onboarding "daily
> learning goal" question (5/10/15/20). Its `description` is also generated
> dynamically, e.g. `"Spend 10 minutes learning"`. `FirestoreService._reconcileQuests()`
> compares both target and description against the pool, so a text-only
> change like this still triggers reconciliation instead of waiting for
> tomorrow's regeneration (progress/collected are only reset when the
> *target* actually changed, not on a description-only drift).
>
> `high_score_lessons` only increments from `exercise_screen.dart`'s
> `_finishLesson()`, and only when that lesson's `correctCount / totalCount *
> 100 >= 90` — a learn-mode session finished below 90% doesn't count toward
> the 3, and practice/quiz sessions never count toward this quest at all.
>
> Progress for `spend_minutes` is accumulated in seconds from the wall-clock
> duration of every learn, practice, and quiz session
> (`updateQuestProgress(uid, 'spend_minutes', durationSeconds)`), so it's the
> only quest all three session types feed into — `earn_xp` also counts XP
> from all three, while `high_score_lessons` is learn-mode only.
>
> Quest completion (`progress >= target`) does **not** award XP by itself.
> Reaching `target` only flips `completed: true`. The Quest screen renders
> each quest with a treasure-chest button: muted while `!completed`, shows a
> red "ready" dot once `completed && !collected`. Tapping it while ready
> calls `FirestoreService.collectQuestReward(uid, questId)`, which — in one
> Firestore transaction — sets `collected: true` on the quest and increments
> the user's `totalXp` by that quest's `xpReward`, then shows a short
> "Reward Collected! +N XP" dialog. The reward amount is never shown on the
> quest card itself — only in that one-time collection dialog.

---

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
// lib/core/constants/xp_constants.dart
const kXpLearnCorrect   = 2;      // per question answered correctly — the
                                   // only XP source for learn + practice
                                   // sessions; session XP = correctCount * 2,
                                   // no flat completion bonus
const kXpPracticeEasy   = 15;     // defined, never used
const kXpPracticeMedium = 20;     // defined, never used
const kXpPracticeHard   = 25;     // defined, never used
const kXpPerfectBonus   = 50;     // defined, never used
const kXpStreakBonus     = 100;   // one-time bonus on first 7-day streak
```
There is no `kXpQuestBonus` constant — each quest's XP reward is its own
per-quest `xpReward` value in `kQuestPool` (`lib/data/quest_pool.dart`,
currently 5/20/30), credited only on manual collection — see the Daily
Quests section above.

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
## Amendment — Two-Screen Google Auth (current behaviour)

This supersedes the auth behaviour described in the earlier amendments above
wherever they conflict. See TECH_STACK.md's "Auth Flow" section for the full
code-level walkthrough and rationale; this amendment covers the
Firestore/data-model implications only.

- **Two separate screens, not one:** `LinkAccountScreen` (Create Profile,
  `linkWithCredential` — upgrades the current anonymous session in place,
  same UID, all progress preserved) and `SignInScreen` (Sign In,
  `signInWithCredential` — switches to a different existing account, a
  different UID). See APP_FLOW.md S-25/S-25b for the full behavioural split.
- **`photoUrl`** is a real field on `users/{uid}` (see the User Document
  section above) — populated from the Google account's `photoUrl` at link
  or sign-in time, `''` for anonymous/unlinked users. Sourced from
  `user.providerData`'s `google.com` entry when backfilled by Splash's
  self-heal reconciliation (see TECH_STACK.md), not from `User.photoURL`.
- **No deleted-account blocklist.** There is no `deletedGoogleAccounts`
  collection and no check against one — a deleted account's Google identity
  can always be freely linked or signed into again as a new profile.
- **Sign Out always fully signs out**, unconditionally — no device-local
  heuristic, no `unlink()` special case. See TECH_STACK.md for why the
  earlier `native_anonymous_uid`-based heuristic was removed.
- **Delete Account ordering:** `AuthService.reauthenticateForDeleteIfNeeded()`
  runs first (no-op if already anonymous), then
  `FirestoreService.deleteUserData(uid)` (all subcollections, then the user
  doc), then `AuthService.deleteAccount()` (`user.delete()`) — see
  `deleteUserData()` in `firestore_service.dart` and the "Delete Account"
  section in TECH_STACK.md for the reauth-ordering and timeout-guard
  rationale.

## Amendment — Gamification / Medals

`medalsEarned: Map<String, bool>` was added to `users/{uid}` (see the User
Document section above). Full behaviour — award conditions, tiers, and every
UI surface — is documented in **GAMIFICATION.md**, not duplicated here.
